// Native runtime check only. The production builder still requires the real bitstream.
const { cpSync, mkdtempSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { pathToFileURL } = require('node:url');
const { createHash } = require('node:crypto');
(async()=>{
  if(process.platform!=='linux'||process.arch!=='x64')throw Error('Esta comprobación requiere Linux x86_64.');
  const software=resolve(process.argv[2]||resolve(__dirname,'..'));
  const version=JSON.parse(readFileSync(resolve(software,'gui/package.json'),'utf8')).version;
  const stage=mkdtempSync(resolve(software,`build/native-gui-${version}-`));
  const appSource=mkdtempSync(resolve(software,'build/gui-asar-source-'));
  try {
    cpSync(resolve(software,'gui/node_modules/electron/dist'),stage,{recursive:true});
    renameSync(resolve(stage,'electron'),resolve(stage,'viewrv-gui'));
    cpSync(resolve(software,'build/python/viewrv'),stage,{recursive:true});
    cpSync(resolve(software,'build/python/viewrv-core'),resolve(stage,'resources/core'),{recursive:true});
    for(const directory of ['content','hardware','programmer'])cpSync(resolve(software,'resources',directory),resolve(stage,'resources',directory),{recursive:true});
    cpSync(resolve(software,'gui/out'),resolve(appSource,'out'),{recursive:true});
    cpSync(resolve(software,'gui/package.json'),resolve(appSource,'package.json'));
    const asar=await import(pathToFileURL(resolve(software,'gui/node_modules/@electron/asar/lib/asar.js')));
    await asar.createPackage(appSource,resolve(stage,'resources/app.asar'));
    writeFileSync(resolve(stage,'VERIFICATION-ONLY.txt'),'Comprobación temporal de runtimes nativos y ASAR. Sin release.json ni bitstream: no es una distribución de hardware.\n');
    const files=['viewrv-gui','viewrv','resources/core/viewrv-core','resources/app.asar'];
    writeFileSync(resolve(stage,'verification-sha256.json'),JSON.stringify(Object.fromEntries(files.map(name=>[name,createHash('sha256').update(readFileSync(resolve(stage,name))).digest('hex')])),null,2)+'\n');
    console.log(stage);
  } catch(error) { rmSync(stage,{recursive:true,force:true});throw error }
  finally { rmSync(appSource,{recursive:true,force:true}) }
})().catch(error=>{console.error(error);process.exitCode=1});
