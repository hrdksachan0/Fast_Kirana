import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import sharp from 'sharp'

async function optimizeImageToWebP(inputBuffer: Buffer): Promise<{ buffer: Buffer; isWebP: boolean }> {
  try {
    const optimized = await sharp(inputBuffer)
      .resize({
        width: 800,
        withoutEnlargement: true,
        fit: 'inside',
      })
      .webp({ quality: 80, effort: 4 })
      .toBuffer()
    return { buffer: optimized, isWebP: true }
  } catch (err) {
    console.warn('[WebP Optimization] Compression fallback to original:', err)
    return { buffer: inputBuffer, isWebP: false }
  }
}

async function uploadToCloudinary(
  base64Image: string,
  cloudName: string,
  uploadPreset: string
): Promise<string> {
  let fileData = base64Image
  if (!fileData.startsWith('data:')) {
    fileData = `data:image/webp;base64,${base64Image}`
  }

  const formData = new FormData()
  formData.append('file', fileData)
  formData.append('upload_preset', uploadPreset)

  const res = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
    method: 'POST',
    body: formData,
  })

  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`Cloudinary upload failed: ${res.statusText} - ${errText}`)
  }

  const data = await res.json()
  return data.secure_url || data.url
}

export async function POST(req: Request) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const contentType = req.headers.get('content-type') || ''
    let inputBuffer: Buffer | null = null

    if (contentType.includes('multipart/form-data')) {
      const formData = await req.formData()
      const file = formData.get('file') as File | null
      if (!file) {
        return NextResponse.json({ error: 'No file provided' }, { status: 400 })
      }
      const arrayBuffer = await file.arrayBuffer()
      inputBuffer = Buffer.from(arrayBuffer)
    } else {
      const body = await req.json()
      const rawData = body.file || body.image || ''
      if (rawData) {
        // Strip data URL prefix if present
        const base64Clean = rawData.includes(',') ? rawData.split(',')[1] : rawData
        inputBuffer = Buffer.from(base64Clean, 'base64')
      }
    }

    if (!inputBuffer || inputBuffer.length === 0) {
      return NextResponse.json({ error: 'No image data provided' }, { status: 400 })
    }

    // Auto-compress to WebP (max 800px width, quality 80)
    const { buffer: optimizedBuffer, isWebP } = await optimizeImageToWebP(inputBuffer)
    const mime = isWebP ? 'image/webp' : 'image/jpeg'
    const base64Data = `data:${mime};base64,${optimizedBuffer.toString('base64')}`

    // Try Cloudinary if configured in Settings
    try {
      const settings = await prisma.storeSetting.findMany({
        where: { key: { in: ['cloudinary_cloud_name', 'cloudinary_upload_preset'] } }
      })
      const map = settings.reduce((acc, s) => ({ ...acc, [s.key]: s.value }), {} as Record<string, string>)
      if (map.cloudinary_cloud_name && map.cloudinary_upload_preset) {
        const cloudinaryUrl = await uploadToCloudinary(base64Data, map.cloudinary_cloud_name, map.cloudinary_upload_preset)
        return NextResponse.json({ success: true, url: cloudinaryUrl })
      }
    } catch (e) {
      console.warn('Cloudinary upload skipped, using fallback:', e)
    }

    // Return Data URL (works instantly everywhere)
    return NextResponse.json({ success: true, url: base64Data })
  } catch (err: any) {
    console.error('Image Upload API Error:', err)
    return NextResponse.json({ error: err.message || 'Image upload failed' }, { status: 500 })
  }
}
