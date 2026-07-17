export type DriveUploadInput = {
  folderId: string
  file: File
  name: string
}

export type DriveUploadResult = {
  fileId: string
  webViewLink?: string
}

export type DriveClient = {
  uploadDiaryPhoto(input: DriveUploadInput): Promise<DriveUploadResult>
}

export function createDriveClient(fetcher: typeof fetch = fetch): DriveClient {
  return {
    async uploadDiaryPhoto(input) {
      const body = new FormData()
      body.set('folderId', input.folderId)
      body.set('name', input.name)
      body.set('file', input.file)
      const response = await fetcher('/api/drive/diary-photo', { method: 'POST', body })
      if (!response.ok) throw new Error('Falha ao enviar foto para o Drive')
      return await response.json() as DriveUploadResult
    },
  }
}
