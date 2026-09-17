/**
 * Standardized API response helpers for consistent response format with Request ID correlation.
 *
 * Usage:
 *   import { ApiResponder } from '@/lib/api-response'
 *
 *   return ApiResponder.success({ products }, { total, page, limit }, 200, req)
 *   return ApiResponder.error('Product not found', 404, 'NOT_FOUND', null, req)
 */

import { NextResponse } from 'next/server'
import crypto from 'crypto'

export interface ApiMeta {
  total?: number
  page?: number
  limit?: number
  [key: string]: unknown
}

export type ApiErrorCode =
  | 'VALIDATION_ERROR'
  | 'NOT_FOUND'
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'INSUFFICIENT_STOCK'
  | 'STORE_OFFLINE'
  | 'PAYMENT_FAILED'
  | 'RATE_LIMITED'
  | 'INTERNAL_ERROR'
  | 'CONFLICT'
  | 'BAD_REQUEST'

export interface ApiResponse<T = unknown> {
  success: boolean
  data?: T
  error?: string
  code?: ApiErrorCode | string
  details?: unknown
  meta?: ApiMeta
  requestId: string
  timestamp: string
}

function resolveRequestId(req?: Request | Headers | string): string {
  if (!req) return crypto.randomUUID()
  if (typeof req === 'string') return req
  if ('headers' in req && req.headers && typeof req.headers.get === 'function') {
    return req.headers.get('x-request-id') || crypto.randomUUID()
  }
  if (typeof (req as Headers).get === 'function') {
    return (req as Headers).get('x-request-id') || crypto.randomUUID()
  }
  return crypto.randomUUID()
}

export class ApiResponder {
  /**
   * Standardized successful response.
   */
  static success<T>(
    data: T,
    meta?: ApiMeta,
    status = 200,
    req?: Request | Headers | string
  ): NextResponse {
    const requestId = resolveRequestId(req)
    const body: ApiResponse<T> = {
      success: true,
      data,
      requestId,
      timestamp: new Date().toISOString(),
    }
    if (meta) body.meta = meta

    return NextResponse.json(body, {
      status,
      headers: {
        'x-request-id': requestId,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-user-id, x-request-id',
      },
    })
  }

  /**
   * Standardized error response with typed error code and tracking correlation ID.
   */
  static error(
    message: string,
    status = 400,
    code: ApiErrorCode | string = 'BAD_REQUEST',
    details?: unknown,
    req?: Request | Headers | string
  ): NextResponse {
    const requestId = resolveRequestId(req)
    const isDev = process.env.NODE_ENV !== 'production'

    const body: ApiResponse = {
      success: false,
      error: message,
      code,
      requestId,
      timestamp: new Date().toISOString(),
      ...(details && isDev ? { details } : {}),
    }

    return NextResponse.json(body, {
      status,
      headers: {
        'x-request-id': requestId,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-user-id, x-request-id',
      },
    })
  }
}
