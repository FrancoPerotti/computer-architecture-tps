// Translate pinned native metadata through explicit bindings; geometry stays in XML.
const path=require('node:path');
const zlib=require('node:zlib');
const {DOMParser}=require(require.resolve('@xmldom/xmldom',{paths:[path.resolve(__dirname,'../gui')]}));
const unpack=value=>decodeURIComponent(zlib.inflateRawSync(Buffer.from(value,'base64')).toString());
function graphCells(xml){
  const reject=message=>{throw Error('XML del circuito inválido: '+message)};
  const parse=value=>{
    if(/<!DOCTYPE|<!ENTITY/i.test(value))reject('declaraciones externas no admitidas');
    const doc=new DOMParser({errorHandler:{warning:reject,error:reject,fatalError:reject}}).parseFromString(value,'text/xml');
    if(!doc?.documentElement)reject('documento vacío');return doc;
  };
  const doc=parse(xml),diagrams=Array.from(doc.getElementsByTagName('diagram'));
  let model;
  if(doc.documentElement.tagName==='mxGraphModel')model=doc.documentElement;
  else{
    if(diagrams.length!==1)reject('se requiere el dibujo completo en una sola página');
    const diagram=diagrams[0];model=diagram.getElementsByTagName('mxGraphModel')[0];
    if(!model)model=parse(unpack(diagram.textContent.trim())).documentElement;
  }
  if(model?.tagName!=='mxGraphModel')reject('falta mxGraphModel');
  const cells=new Map();
  for(const element of Array.from(model.getElementsByTagName('*'))){
    if(!element.hasAttribute('id'))continue;
    const id=element.getAttribute('id');
    if(!id||cells.has(id))reject('ID vacío o repetido: '+id);
    cells.set(id,element);
  }
  if(!cells.has('0')||!cells.has('1'))reject('faltan las raíces nativas');
  for(const element of Array.from(model.getElementsByTagName('mxCell'))){
    for(const attribute of ['parent','source','target']){
      const reference=element.getAttribute(attribute);
      if(reference&&!cells.has(reference))reject('referencia '+attribute+' inexistente: '+reference);
    }
  }
  for(const tag of ['mxGeometry','mxPoint'])for(const element of Array.from(model.getElementsByTagName(tag))){
    for(const attribute of ['x','y','width','height'])if(element.hasAttribute(attribute)&&!Number.isFinite(Number(element.getAttribute(attribute))))reject('coordenada inválida: '+attribute);
  }
  return cells;
}
function prepareGraph(data,bindings,xml){
  const sourceXML=unpack(data.xml),sourceCells=graphCells(sourceXML),currentCells=graphCells(xml);
  const sourceBlocks=bindings.source_blocks,blocks=bindings.blocks,aliases=new Map();
  if(!sourceBlocks||Object.keys(sourceBlocks).length!==44||Object.keys(blocks).length!==44||Object.keys(sourceBlocks).some(block=>!Object.hasOwn(blocks,block)))throw Error('Los bindings deben conservar los 44 source_blocks aprobados.');
  const add=(source,target)=>{
    if(typeof source!=='string'||typeof target!=='string'||!sourceCells.has(source)||!currentCells.has(target)||['0','1'].includes(source)||['0','1'].includes(target))throw Error('Binding de celda inexistente o reservado: '+source+' → '+target);
    if(aliases.has(source)&&aliases.get(source)!==target)throw Error('Binding contradictorio para '+source);
    aliases.set(source,target);
  };
  for(const [block,source] of Object.entries(sourceBlocks))add(source,blocks[block]);
  const originalRepresentations=bindings.source_representations||{},representations=bindings.representations||{};
  if(Object.keys(representations).some(block=>!Object.hasOwn(originalRepresentations,block)))throw Error('La representación carece de referencia de origen.');
  for(const [block,sources] of Object.entries(originalRepresentations)){
    const targets=representations[block];
    if(!Object.hasOwn(blocks,block)||!Array.isArray(sources)||!Array.isArray(targets)||!sources.length||sources.length!==targets.length)throw Error('Representación alternativa incompleta: '+block);
    sources.forEach((source,index)=>add(source,targets[index]));
  }
  for(const [source,target] of Object.entries(bindings.cell_ids||{}))add(source,target);
  const identities=new Set();
  for(const source of sourceCells.keys()){
    const target=aliases.get(source)||source;
    if(identities.has(target))throw Error('Dos celdas de origen comparten ID de destino: '+target);
    identities.add(target);
  }
  const translate=value=>{
    if(typeof value!=='string')return value;
    const result=aliases.get(value)||value;
    if(sourceCells.has(value)&&!currentCells.has(result))throw Error('Referencia gráfica sin celda actual: '+value+'; actualizar cell_ids.');
    return result;
  };
  function remap(value){
    if(Array.isArray(value))return value.map(remap);
    if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([key,value])=>[translate(key),remap(value)]));
    return translate(value);
  }
  const result=remap(data);
  const native=element=>element.tagName==='mxCell'?element:element.getElementsByTagName('mxCell')[0];
  for(const [id,element] of sourceCells){
    const current=currentCells.get(aliases.get(id)||id),before=native(element),after=current?native(current):null;
    if(before?.getAttribute('edge')!=='1'||!after)continue;
    for(const attribute of ['source','target']){
      const original=before.getAttribute(attribute)||'',expected=aliases.get(original)||original;
      if((after.getAttribute(attribute)||'')!==expected)throw Error('Los extremos de una conexión cambiaron: '+id+'; revisar la semántica del dibujo.');
    }
  }
  for(const block of Object.keys(blocks)){
    const target=representations[block]?.[0]||blocks[block];
    if(!Object.hasOwn(result.blocks,target))throw Error('Módulo sin metadatos aprobados: '+block);
  }
  result.viewrv_refresh_cameras=xml!==sourceXML;
  return result;
}
module.exports={graphCells,prepareGraph};

function applyEducation(data,education,bindings){
  const cell=block=>bindings.representations?.[block]?.[0]||bindings.blocks[block];
  const mapped=table=>Object.fromEntries(Object.entries(table||{}).map(([block,text])=>{
    if(!Object.hasOwn(bindings.blocks,block)||typeof text!=='string')throw Error('Referencia educativa de módulo inválida: '+block);
    return [cell(block),text];
  }));
  const connections=new Map(data.connections.map(row=>[row.id,row]));
  if(Object.keys(education.connections||{}).length!==connections.size)throw Error('Catálogo de conexiones incompleto.');
  for(const [id,text] of Object.entries(education.connections)){
    const connection=connections.get(id);
    if(!connection||typeof text.description!=='string')throw Error('Explicación de conexión inválida: '+id);
    connection.description=text.description;
    if(Object.hasOwn(text,'target_function')){if(typeof text.target_function!=='string')throw Error('Función de destino inválida: '+id);connection.target_function=text.target_function;}
  }
  function pageConnections(page,explanations,note){
    if(!explanations||!Array.isArray(note)||note.some(text=>typeof text!=='string'))throw Error('Faltan explicaciones de conexiones: '+page.id);
    const active=new Set();
    for(const [id,detail] of Object.entries(page.connections)){
      if(detail.kind){
        active.add(id);const text=explanations[id];
        if(!text||typeof text.description!=='string'||!Array.isArray(text.paragraphs)||text.paragraphs.some(value=>typeof value!=='string'))throw Error('Explicación contextual incompleta: '+page.id+'/'+id);
        detail.description=text.description;detail.paragraphs=text.paragraphs;
      }else{
        const contextual=detail.paragraphs.length>1,description=connections.get(id).description;
        detail.description=description;detail.paragraphs=[description,...(contextual?note:[])];
      }
    }
    if(Object.keys(explanations).some(id=>!active.has(id)))throw Error('Referencia de conexión contextual inexistente: '+page.id);
  }
  const pages=new Map(data.pages.map(page=>[page.id,page])),overview=pages.get(data.presentation.overview.id);
  overview.paragraphs=education.assumptions;
  pageConnections(overview,education.overview_connection_explanations,education.overview_inactive_connection_note);
  if(!Array.isArray(education.stage_presentation)||education.stage_presentation.length!==5)throw Error('Faltan los textos generales de etapas.');
  data.presentation.stages=education.stage_presentation;
  if(!education.signals||Object.keys(data.signals).some(id=>!Object.hasOwn(education.signals,id)))throw Error('Faltan explicaciones de señales.');
  data.signals=education.signals;
  for(const [id,instruction] of Object.entries(education.instructions)){
    const entry=data.instructions[id];
    if(!entry||instruction.stages.length!==5)throw Error('Instrucción o etapas incompletas: '+id);
    for(const key of ['name','example','equation','description','route_description','signals'])entry[key]=instruction[key];
    entry.module_explanations=mapped(instruction.module_explanations);
    instruction.stages.forEach((stage,index)=>{
      if(stage.stage!==['IF','ID','EX','MEM','WB'][index])throw Error('Etapas desordenadas: '+id);
      const page=pages.get(entry.stages[index].id);
      Object.assign(page,{name:stage.title,description:stage.description,operation:stage.operation,paragraphs:stage.paragraphs,controls:stage.controls,module_explanations:mapped(stage.module_explanations)});
      pageConnections(page,stage.connection_explanations,stage.inactive_connection_note);
    });
  }
  for(const [block,entry] of Object.entries(education.modules)){
    const id=cell(block);
    if(!data.blocks[id])throw Error('Módulo educativo sin representación: '+block);
    Object.assign(data.blocks[id],{name:entry.title,function:entry.description,external:entry.external_signals,io:{inputs:entry.inputs,outputs:entry.outputs}});
    if(entry.presentation)data.module_presentation[id]=entry.presentation;
    else delete data.module_presentation[id];
  }
}
module.exports.applyEducation=applyEducation;
