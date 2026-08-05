import fs from 'fs'

async function main() {
  const filePath = 'C:/Users/Sooraj/.gemini/antigravity/brain/88ec981f-f0e5-4b42-861f-956b1f5165be/north_indian_banner_1785657502107.jpg'
  const fileBuffer = fs.readFileSync(filePath)
  const base64Image = `data:image/jpeg;base64,${fileBuffer.toString('base64')}`

  const cloudName = 'dbf3lhk94'
  const uploadPreset = 'fastkirana'

  console.log('Uploading North Indian banner to Cloudinary...')

  const formData = new FormData()
  formData.append('file', base64Image)
  formData.append('upload_preset', uploadPreset)

  const res = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
    method: 'POST',
    body: formData,
  })

  const data = await res.json()
  console.log('=== UPLOAD SUCCESSFUL ===')
  console.log('Cloudinary URL:', data.secure_url)
}

main().catch(console.error)
