import { describe, expect, it, vi } from 'vitest'
import { createDriveClient, diaryPhotoFileName, diaryPhotoPath } from './driveClient'

describe('driveClient', () => {
  it('isola upload em fetch substituivel', async () => {
    const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ fileId: 'file-1' }) })
    const file = new File(['foto'], 'foto.jpg', { type: 'image/jpeg' })

    const input = { organizationId: 'org-1', professionalId: 'pro-1', patientId: 'patient-1', mealId: 'meal-1', mealLabel: 'Almoço', occurredOn: '2026-07-17', checkinId: 'abcdef123456', file }

    await expect(createDriveClient(fetcher as never).uploadDiaryPhoto(input)).resolves.toEqual({ fileId: 'file-1' })
    expect(fetcher).toHaveBeenCalledWith('/api/drive/diary-photo', expect.objectContaining({ method: 'POST' }))
    expect(diaryPhotoFileName(input)).toBe('2026-07-17-almoco-abcdef12.jpg')
    expect(diaryPhotoPath(input)).toEqual(['org-1', 'pro-1', 'patient-1', '2026-07'])
  })
})
