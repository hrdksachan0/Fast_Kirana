import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import sharp from 'sharp'
import { uploadToSupabaseStorage, generateStoragePath } from '@/lib/supabase-storage'

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
    const ext = isWebP ? 'webp' : 'jpg'

    // Upload to Supabase Storage
    try {
      const storagePath = generateStoragePath('products', ext)
      const publicUrl = await uploadToSupabaseStorage(optimizedBuffer, storagePath, mime)
      return NextResponse.json({ success: true, url: publicUrl })
    } catch (storageErr) {
      console.error('[Supabase Storage] Upload failed, falling back to data URL:', storageErr)
    }

    // Fallback: Return Data URL (works instantly everywhere)
    const base64Data = `data:${mime};base64,${optimizedBuffer.toString('base64')}`
    return NextResponse.json({ success: true, url: base64Data })
  } catch (err: any) {
    console.error('Image Upload API Error:', err)
    return NextResponse.json({ error: err.message || 'Image upload failed' }, { status: 500 })
  }
}
