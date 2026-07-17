import { describe, expect, it, vi } from 'vitest'
import { createDriveClient } from './driveClient'

describe('driveClient', () => {
  it('isola upload em fetch substituivel', async () => {
    const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ fileId: 'file-1' }) })
    const file = new File(['foto'], 'foto.jpg', { type: 'image/jpeg' })

    await expect(createDriveClient(fetcher as never).uploadDiaryPhoto({ folderId: 'folder-1', file, name: 'foto.jpg' })).resolves.toEqual({ fileId: 'file-1' })
    expect(fetcher).toHaveBeenCalledWith('/api/drive/diary-photo', expect.objectContaining({ method: 'POST' }))
  })
})
