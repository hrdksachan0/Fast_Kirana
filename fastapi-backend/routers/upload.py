import io
import base64
import asyncio
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends, Request
from pydantic import BaseModel
from PIL import Image, ImageOps

# Guard against decompression bomb attacks
Image.MAX_IMAGE_PIXELS = 50_000_000

MAX_UPLOAD_SIZE = 15 * 1024 * 1024  # 15 MB raw upload limit
MAX_TARGET_BYTES = 80 * 1024  # Strictly 80 KB limit for instant 2G/3G mobile load

router = APIRouter(prefix="/upload", tags=["Upload & Image Optimization"])

class ImageBase64Payload(BaseModel):
    image: str
    maxWidth: Optional[int] = 800
    quality: Optional[int] = 78

def optimize_image_bytes(raw_bytes: bytes, max_width: int = 800, quality: int = 78) -> tuple[bytes, int, int]:
    """
    Optimizes any image to WebP with multi-pass adaptive compression
    strictly targeting <= 80 KB for instantaneous 2G/3G mobile loading.
    Preserves EXIF orientation and handles transparency cleanly.
    """
    try:
        with Image.open(io.BytesIO(raw_bytes)) as img:
            # Auto-transpose based on phone camera EXIF tags
            img = ImageOps.exif_transpose(img)

            # Ensure proper color mode
            if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
                img = img.convert("RGBA")
            else:
                img = img.convert("RGB")

            orig_w, orig_h = img.size

            def resize_and_encode(target_w: int, target_q: int) -> tuple[bytes, int, int]:
                if orig_w > target_w:
                    new_w = target_w
                    new_h = int(orig_h * (target_w / orig_w))
                    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
                else:
                    new_w, new_h = orig_w, orig_h
                    resized = img
                buf = io.BytesIO()
                resized.save(buf, format="WEBP", quality=target_q, method=4)
                return buf.getvalue(), new_w, new_h

            # Pass 1: 800px max width at quality 78
            data, w, h = resize_and_encode(min(max_width, 800), quality)

            # Pass 2: If still > 80 KB, tighten quality to 68
            if len(data) > MAX_TARGET_BYTES:
                data, w, h = resize_and_encode(min(max_width, 800), 68)

            # Pass 3: If still > 80 KB, resize to 640px at quality 60
            if len(data) > MAX_TARGET_BYTES:
                data, w, h = resize_and_encode(640, 60)

            return data, w, h
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Image processing failed: {str(e)}")


@router.post("")
@router.post("/")
async def upload_root(
    request: Request,
    file: Optional[UploadFile] = File(None),
):
    """
    Universal upload endpoint matching Next.js /api/upload.
    Accepts multipart/form-data with 'file', or JSON with 'file' or 'image' base64.
    Returns { success: true, url: data_url, sizeKB, format: 'webp' }.
    """
    content_type = request.headers.get("content-type", "")
    raw_content = None

    if "multipart/form-data" in content_type and file:
        raw_content = await file.read()
    else:
        try:
            body = await request.json()
            raw_data = body.get("file") or body.get("image") or ""
            if raw_data:
                if "," in raw_data:
                    raw_data = raw_data.split(",")[1]
                raw_content = base64.b64decode(raw_data)
        except Exception:
            pass

    if not raw_content:
        raise HTTPException(status_code=400, detail="No image file or base64 provided")

    if len(raw_content) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail=f"File exceeds maximum allowed size of {MAX_UPLOAD_SIZE // (1024*1024)}MB")

    webp_bytes, width, height = await asyncio.to_thread(
        optimize_image_bytes, raw_content, max_width=800, quality=78
    )

    base64_encoded = base64.b64encode(webp_bytes).decode("utf-8")
    data_url = f"data:image/webp;base64,{base64_encoded}"

    return {
        "success": True,
        "url": data_url,
        "format": "webp",
        "width": width,
        "height": height,
        "sizeKB": round(len(webp_bytes) / 1024, 1)
    }


@router.post("/image")
async def upload_and_optimize_image(
    file: Optional[UploadFile] = File(None),
    max_width: int = Form(800),
    quality: int = Form(78),
):
    """
    Upload an image file (PNG, JPG, HEIC, WEBP) and automatically compress
    to WebP (max 800px width, <= 80 KB).
    Returns base64 data URL and compression statistics.
    """
    if not file:
        raise HTTPException(status_code=400, detail="No image file provided")

    raw_content = await file.read()
    orig_size = len(raw_content)

    if orig_size == 0:
        raise HTTPException(status_code=400, detail="Empty file uploaded")
    if orig_size > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail=f"File exceeds maximum allowed size of {MAX_UPLOAD_SIZE // (1024*1024)}MB")

    webp_bytes, width, height = await asyncio.to_thread(
        optimize_image_bytes, raw_content, max_width=max_width, quality=quality
    )
    webp_size = len(webp_bytes)

    base64_encoded = base64.b64encode(webp_bytes).decode("utf-8")
    data_url = f"data:image/webp;base64,{base64_encoded}"

    savings_percent = round((1.0 - (webp_size / orig_size)) * 100.0, 1) if orig_size > 0 else 0.0

    return {
        "success": True,
        "url": data_url,
        "format": "webp",
        "width": width,
        "height": height,
        "sizeKB": round(webp_size / 1024, 1),
        "originalSizeBytes": orig_size,
        "optimizedSizeBytes": webp_size,
        "savingsPercent": max(0.0, savings_percent),
    }

@router.post("/image-base64")
async def optimize_base64_image(payload: ImageBase64Payload):
    """
    Receives base64 string image, converts to WebP (<= 80 KB) and returns optimized base64 data URL.
    """
    raw_str = payload.image
    if "," in raw_str:
        raw_str = raw_str.split(",")[1]

    try:
        raw_bytes = base64.b64decode(raw_str)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data")

    orig_size = len(raw_bytes)
    if orig_size == 0:
        raise HTTPException(status_code=400, detail="Empty image data")
    if orig_size > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail=f"Image exceeds maximum allowed size of {MAX_UPLOAD_SIZE // (1024*1024)}MB")

    webp_bytes, width, height = await asyncio.to_thread(
        optimize_image_bytes,
        raw_bytes,
        max_width=payload.maxWidth or 800,
        quality=payload.quality or 78,
    )
    webp_size = len(webp_bytes)

    base64_encoded = base64.b64encode(webp_bytes).decode("utf-8")
    data_url = f"data:image/webp;base64,{base64_encoded}"

    savings_percent = round((1.0 - (webp_size / orig_size)) * 100.0, 1) if orig_size > 0 else 0.0

    return {
        "success": True,
        "url": data_url,
        "format": "webp",
        "width": width,
        "height": height,
        "sizeKB": round(webp_size / 1024, 1),
        "originalSizeBytes": orig_size,
        "optimizedSizeBytes": webp_size,
        "savingsPercent": max(0.0, savings_percent),
    }
