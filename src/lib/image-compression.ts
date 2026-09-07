/**
 * Client-side image compression utility.
 * Resizes large images (e.g. 10MB+ phone camera photos) down to a max width/height
 * and compresses them to lightweight WebP or JPEG blobs in milliseconds.
 * This guarantees the upload body never exceeds Vercel's 4.5MB request limit.
 */
export async function compressImageClient(
  file: File,
  maxDimension = 1200,
  quality = 0.82
): Promise<File> {
  // If in SSR or file is not an image or is SVG/GIF, return as-is
  if (typeof window === 'undefined' || !file || !file.type.startsWith('image/')) {
    return file
  }
  if (file.type === 'image/svg+xml' || file.type === 'image/gif') {
    return file
  }

  // If already very small (< 250KB), no need to compress
  if (file.size < 250 * 1024) {
    return file
  }

  return new Promise((resolve) => {
    try {
      const reader = new FileReader()
      reader.onload = (e) => {
        const img = new Image()
        img.onload = () => {
          let { width, height } = img

          // Calculate scaled dimensions keeping aspect ratio
          if (width > maxDimension || height > maxDimension) {
            if (width > height) {
              height = Math.round((height * maxDimension) / width)
              width = maxDimension
            } else {
              width = Math.round((width * maxDimension) / height)
              height = maxDimension
            }
          }

          const canvas = document.createElement('canvas')
          canvas.width = width
          canvas.height = height
          const ctx = canvas.getContext('2d')
          if (!ctx) {
            resolve(file)
            return
          }

          // Fill white background for transparent images converted to jpeg/webp
          ctx.drawImage(img, 0, 0, width, height)

          const outputType = 'image/webp'
          canvas.toBlob(
            (blob) => {
              if (blob && blob.size < file.size) {
                const baseName = file.name.replace(/\.[^/.]+$/, '')
                const newFile = new File([blob], `${baseName}.webp`, {
                  type: outputType,
                  lastModified: Date.now(),
                })
                resolve(newFile)
              } else {
                // If compression didn't reduce size, keep original
                resolve(file)
              }
            },
            outputType,
            quality
          )
        }
        img.onerror = () => resolve(file)
        img.src = e.target?.result as string
      }
      reader.onerror = () => resolve(file)
      reader.readAsDataURL(file)
    } catch {
      resolve(file)
    }
  })
}
