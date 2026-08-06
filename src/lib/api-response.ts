/**
 * Standardized API response helpers for consistent response format.
 *
 * Usage:
 *   import { ApiResponder } from '@/lib/api-response'
 *
 *   return ApiResponder.success({ products }, { total, page, limit })
 *   return ApiResponder.error('Product not found', 404)
 *   return ApiResponder.success('Created', {}, 201)
 */

import { NextResponse } from 'next/server'

export interface ApiMeta {
  total?: number
  page?: number
  limit?: number
  [key: string]: unknown
}

export interface ApiResponse<T = any> {
  success: boolean
  data?: T
  error?: string
  details?: unknown
  meta?: ApiMeta
}

export class ApiResponder {
  /**
   * Successful response.
   * @param data - Response payload
   * @param meta - Optional metadata (total, page, limit, etc.)
   * @param status - HTTP status code (default 200)
   */
  static success<T>(
    data: T,
    meta?: ApiMeta,
    status = 200
  ): NextResponse {
    const body: ApiResponse<T> = { success: true, data }
    if (meta) body.meta = meta

    return NextResponse.json(body, { status })
  }

  /**
   * Error response.
   * @param message - Error message
   * @param status - HTTP status code (default 400)
   * @param details - Optional error details for debugging (not exposed in production)
   */
  static error(
    message: string,
    status = 400,
    details?: unknown
  ): NextResponse {
    const body: ApiResponse = {
      success: false,
      error: message,
      ...(process.env.NODE_ENV === 'development' && details ? { details } : {}),
    }

    return NextResponse.json(body, { status })
  }
}
