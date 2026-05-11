type HarmonyAlbumBridge = {
  saveImageToAlbum?: (base64DataUrl: string, fileName: string) => Promise<string> | string
}

declare global {
  interface Window {
    photoBorderAlbum?: HarmonyAlbumBridge
  }
}

export function canUseHarmonyAlbumExport() {
  return __HARMONY_RAWFILE__ && typeof window.photoBorderAlbum?.saveImageToAlbum === 'function'
}

export async function saveImageBlob(blob: Blob, fileName: string) {
  if (canUseHarmonyAlbumExport() && window.photoBorderAlbum?.saveImageToAlbum) {
    const base64DataUrl = await blobToDataUrl(blob)
    await Promise.resolve(window.photoBorderAlbum.saveImageToAlbum(base64DataUrl, fileName))
    return 'album' as const
  }

  if (__HARMONY_RAWFILE__) {
    throw new Error('HarmonyOS 相册导出桥未初始化，请重新打包并安装应用。')
  }

  const outputUrl = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = outputUrl
  link.download = fileName
  link.click()
  window.setTimeout(() => URL.revokeObjectURL(outputUrl), 0)
  return 'download' as const
}

function blobToDataUrl(blob: Blob) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()

    reader.addEventListener('load', () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result)
        return
      }

      reject(new Error('Failed to convert image for HarmonyOS album export.'))
    })
    reader.addEventListener('error', () => reject(reader.error ?? new Error('Failed to read exported image.')))
    reader.readAsDataURL(blob)
  })
}
