import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

async function uploadToCloudinary(
  base64Image: string,
  cloudName: string,
  uploadPreset: string
): Promise<string> {
  let fileData = base64Image
  if (!fileData.startsWith('data:')) {
    fileData = `data:image/jpeg;base64,${base64Image}`
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
    let base64Data = ''

    if (contentType.includes('multipart/form-data')) {
      const formData = await req.formData()
      const file = formData.get('file') as File | null
      if (!file) {
        return NextResponse.json({ error: 'No file provided' }, { status: 400 })
      }
      const buffer = await file.arrayBuffer()
      const mime = file.type || 'image/jpeg'
      base64Data = `data:${mime};base64,${Buffer.from(buffer).toString('base64')}`
    } else {
      const body = await req.json()
      base64Data = body.file || body.image || ''
    }

    if (!base64Data) {
      return NextResponse.json({ error: 'No image data provided' }, { status: 400 })
    }

    // Try Cloudinary if configured in Settings
    try {
      const settings = await prisma.setting.findMany({
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
