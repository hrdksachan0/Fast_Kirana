import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bberzasmxwioxjynbuaf.supabase.co'
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'sb_publishable_txJDOmH1qWQuOLCKrnV69A_RQ1XS4o-'

// Server-side Supabase client for Storage uploads
// Uses anon key with public bucket (RLS policies allow uploads)
const supabaseStorage = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: false },
})

const BUCKET_NAME = 'fastkirana-images'

/**
 * Upload a buffer to Supabase Storage and return the public URL.
 * 
 * @param buffer - The image buffer to upload
 * @param path - The storage path (e.g., 'products/my-product.webp')
 * @param contentType - MIME type (default: 'image/webp')
 * @returns The public URL of the uploaded image
 */
export async function uploadToSupabaseStorage(
  buffer: Buffer,
  path: string,
  contentType: string = 'image/webp'
): Promise<string> {
  const { data, error } = await supabaseStorage.storage
    .from(BUCKET_NAME)
    .upload(path, buffer, {
      contentType,
      upsert: true, // Overwrite if exists
      cacheControl: '31536000', // 1 year cache
    })

  if (error) {
    throw new Error(`Supabase Storage upload failed: ${error.message}`)
  }

  // Return public URL
  const { data: urlData } = supabaseStorage.storage
    .from(BUCKET_NAME)
    .getPublicUrl(data.path)

  return urlData.publicUrl
}

/**
 * Generate a unique storage path for a file.
 * 
 * @param folder - The folder name (e.g., 'products', 'delivery-photos', 'restaurants', 'categories')
 * @param extension - File extension (default: 'webp')
 * @returns A unique path like 'products/1725638400000-abc123.webp'
 */
export function generateStoragePath(folder: string, extension: string = 'webp'): string {
  const timestamp = Date.now()
  const random = Math.random().toString(36).substring(2, 8)
  return `${folder}/${timestamp}-${random}.${extension}`
}
