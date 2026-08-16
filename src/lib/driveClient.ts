export type DriveUploadInput = {
  file: File
  organizationId: string
  professionalId: string
  patientId: string
  mealId: string
  mealLabel: string
  occurredOn: string
  checkinId: string
}

export type DriveUploadResult = {
  fileId: string
  webViewLink?: string
}

export type DriveClient = {
  uploadDiaryPhoto(input: DriveUploadInput): Promise<DriveUploadResult>
}

export function diaryPhotoFileName(input: Pick<DriveUploadInput, 'occurredOn' | 'mealLabel' | 'checkinId'>): string {
  const meal = input.mealLabel.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'refeicao'
  return `${input.occurredOn}-${meal}-${input.checkinId.slice(0, 8)}.jpg`
}

export function diaryPhotoPath(input: Pick<DriveUploadInput, 'organizationId' | 'professionalId' | 'patientId' | 'occurredOn'>): string[] {
  return [input.organizationId, input.professionalId, input.patientId, input.occurredOn.slice(0, 7)]
}

export function createDriveClient(fetcher: typeof fetch = fetch): DriveClient {
  return {
    async uploadDiaryPhoto(input) {
      const body = new FormData()
      body.set('path', JSON.stringify(diaryPhotoPath(input)))
      body.set('name', diaryPhotoFileName(input))
      body.set('file', input.file)
      const response = await fetcher('/api/drive/diary-photo', { method: 'POST', body })
      if (!response.ok) throw new Error('Falha ao enviar foto para o Drive')
      return await response.json() as DriveUploadResult
    },
  }
}
