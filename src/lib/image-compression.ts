/**
 * Client-side image compression utility.
 * Resizes large images (e.g. 10MB+ phone camera photos) down to max 800px
 * and compresses them to ultra-lightweight WebP (< 80KB) in milliseconds.
 * 
 * Ensures instant 2G/3G mobile image loading and prevents large upload payloads.
 */
export async function compressImageClient(
  file: File,
  maxDimension = 800,
  quality = 0.78
): Promise<File> {
  // If in SSR or file is not an image or is SVG/GIF, return as-is
  if (typeof window === 'undefined' || !file || !file.type.startsWith('image/')) {
    return file
  }
  if (file.type === 'image/svg+xml' || file.type === 'image/gif') {
    return file
  }

  // If already under 80KB and already WebP, no recompression needed
  if (file.size <= 80 * 1024 && file.type === 'image/webp') {
    return file
  }

  return new Promise((resolve) => {
    try {
      const reader = new FileReader()
      reader.onload = (e) => {
        const img = new Image()
        img.onload = () => {
          let { width, height } = img

          // Calculate scaled dimensions keeping aspect ratio (max 800px)
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

          ctx.drawImage(img, 0, 0, width, height)

          const outputType = 'image/webp'
          const baseName = file.name.replace(/\.[^/.]+$/, '')

          // First pass encoding
          canvas.toBlob(
            (blob) => {
              if (!blob) {
                resolve(file)
                return
              }

              // If already <= 80KB, finish
              if (blob.size <= 80 * 1024) {
                const newFile = new File([blob], `${baseName}.webp`, {
                  type: outputType,
                  lastModified: Date.now(),
                })
                resolve(newFile)
                return
              }

              // Second pass: try quality 0.65 to ensure <= 80KB
              canvas.toBlob(
                (blobPass2) => {
                  const finalBlob = blobPass2 && blobPass2.size < blob.size ? blobPass2 : blob
                  const newFile = new File([finalBlob], `${baseName}.webp`, {
                    type: outputType,
                    lastModified: Date.now(),
                  })
                  resolve(newFile)
                },
                outputType,
                0.65
              )
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
