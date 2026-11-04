import { contextBridge, ipcRenderer } from 'electron'

function subscribe(channel: string, callback: () => void): () => void {
  const listener = () => callback()
  ipcRenderer.on(channel, listener)
  return () => ipcRenderer.removeListener(channel, listener)
}
contextBridge.exposeInMainWorld('viewrvDesktop', {
  getCoreConnection: () => ipcRenderer.invoke('viewrv:connection'),
  getRegistrationId: () => ipcRenderer.invoke('viewrv:registration'),
  editCommand: (command: 'cut' | 'copy' | 'paste', text?: string) =>
    ipcRenderer.invoke('viewrv:edit', command, text),
  windowControl: (action: 'minimize' | 'maximize') => ipcRenderer.invoke('viewrv:window', action),
  chooseProgramFile: () => ipcRenderer.invoke('viewrv:file:open'),
  chooseSavePath: (name?: string) => ipcRenderer.invoke('viewrv:file:save', name),
  openLicenses: () => ipcRenderer.invoke('viewrv:licenses'),
  openExternal: (url: string) => ipcRenderer.invoke('viewrv:external', url),
  getZoomFactor: () => ipcRenderer.invoke('viewrv:zoom:get'),
  setZoomFactor: (factor: number) => ipcRenderer.invoke('viewrv:zoom:set', factor),
  requestWindowClose: () => ipcRenderer.invoke('viewrv:close:request'),
  onCloseRequested: (callback: () => void) => subscribe('viewrv:close:requested', callback),
  finishWindowClose: () => ipcRenderer.invoke('viewrv:close:finish'),
})
