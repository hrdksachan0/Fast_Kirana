import io
import base64
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from pydantic import BaseModel
from PIL import Image, ImageOps

router = APIRouter(prefix="/upload", tags=["Upload & Image Optimization"])

class ImageBase64Payload(BaseModel):
    image: str
    maxWidth: Optional[int] = 800
    quality: Optional[int] = 80

def optimize_image_bytes(raw_bytes: bytes, max_width: int = 800, quality: int = 80) -> tuple[bytes, int, int]:
    """
    Optimizes any image to WebP with max_width dimension limit and high-quality compression.
    Preserves EXIF orientation, handles transparency correctly.
    """
    try:
        with Image.open(io.BytesIO(raw_bytes)) as img:
            # Transpose according to EXIF tags if phone was rotated
            img = ImageOps.exif_transpose(img)

            # Ensure proper color mode
            if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
                img = img.convert("RGBA")
            else:
                img = img.convert("RGB")

            # Proportional resize if larger than max_width
            orig_w, orig_h = img.size
            if orig_w > max_width:
                new_w = max_width
                new_h = int(orig_h * (max_width / orig_w))
                img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
            else:
                new_w, new_h = orig_w, orig_h

            # Encode to WebP
            output_buf = io.BytesIO()
            img.save(output_buf, format="WEBP", quality=quality, method=4)
            webp_bytes = output_buf.getvalue()
            return webp_bytes, new_w, new_h
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Image processing failed: {str(e)}")

@router.post("/image")
async def upload_and_optimize_image(
    file: Optional[UploadFile] = File(None),
    max_width: int = Form(800),
    quality: int = Form(80),
):
    """
    Upload an image file (PNG, JPG, HEIC, WEBP) and automatically compress
    to WebP (max 800px width, quality 80).
    Returns base64 data URL and compression statistics.
    """
    if not file:
        raise HTTPException(status_code=400, detail="No image file provided")

    raw_content = await file.read()
    orig_size = len(raw_content)

    if orig_size == 0:
        raise HTTPException(status_code=400, detail="Empty file uploaded")

    webp_bytes, width, height = optimize_image_bytes(raw_content, max_width=max_width, quality=quality)
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
        "originalSizeBytes": orig_size,
        "optimizedSizeBytes": webp_size,
        "savingsPercent": max(0.0, savings_percent),
    }

@router.post("/image-base64")
async def optimize_base64_image(payload: ImageBase64Payload):
    """
    Receives base64 string image, converts to WebP and returns optimized base64 data URL.
    """
    raw_str = payload.image
    if "," in raw_str:
        raw_str = raw_str.split(",")[1]

    try:
        raw_bytes = base64.b64decode(raw_str)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data")

    orig_size = len(raw_bytes)
    webp_bytes, width, height = optimize_image_bytes(
        raw_bytes,
        max_width=payload.maxWidth or 800,
        quality=payload.quality or 80,
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
        "originalSizeBytes": orig_size,
        "optimizedSizeBytes": webp_size,
        "savingsPercent": max(0.0, savings_percent),
    }
