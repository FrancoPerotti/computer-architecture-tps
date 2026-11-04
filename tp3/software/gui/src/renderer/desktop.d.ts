import type { CoreConnection } from '../shared/contracts'
declare global {
  interface Window {
    viewrvDesktop: {
      readonly previewDemo?: { readonly scenario: 'addition' }
      getCoreConnection(): Promise<CoreConnection>
      getRegistrationId(): Promise<string>
      editCommand(command: 'cut' | 'copy' | 'paste', text?: string): Promise<string | null>
      windowControl(action: 'minimize' | 'maximize'): Promise<void>
      chooseProgramFile(): Promise<string | null>
      chooseSavePath(suggestedName?: string): Promise<string | null>
      openLicenses(): Promise<void>
      openExternal(url: string): Promise<void>
      getZoomFactor(): Promise<number>
      setZoomFactor(factor: number): Promise<void>
      requestWindowClose(): Promise<void>
      onCloseRequested(callback: () => void): () => void
      finishWindowClose(): Promise<void>
    }
  }
}
