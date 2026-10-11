import test from 'node:test'
import assert from 'node:assert/strict'
import { tryToParsePath } from 'next/dist/lib/try-to-parse-path'
import nextConfig from '../../../next.config'

test('campaign administration stays local with either FastAPI proxy setting', async () => {
  const previous = process.env.USE_FASTAPI_PROXY
  try {
    for (const mode of ['true', 'false']) {
      process.env.USE_FASTAPI_PROXY = mode
      const rewrites = await nextConfig.rewrites!()
      assert.ok(!Array.isArray(rewrites))
      const rules = [...rewrites.beforeFiles, ...rewrites.afterFiles, ...rewrites.fallback]
      const matches = (pathname: string) =>
        rules.filter((rule) => {
          const parsed = tryToParsePath(rule.source)
          assert.ifError(parsed.error)
          return new RegExp(parsed.regexStr!).test(pathname)
        })
      for (const pathname of [
        '/api/admin/campaign',
        '/api/admin/campaign/',
        '/api/admin/campaign/sub',
      ]) {
        assert.equal(
          matches(pathname).length,
          0,
          `${mode}: ${pathname} bypassed the verified local route`
        )
      }
      for (const pathname of [
        '/api/admin/products',
        '/api/admin/inventory/import',
        '/api/admin/campaign-tools',
      ]) {
        assert.ok(matches(pathname).length > 0, `${mode}: existing proxy lost ${pathname}`)
      }
    }
  } finally {
    if (previous === undefined) delete process.env.USE_FASTAPI_PROXY
    else process.env.USE_FASTAPI_PROXY = previous
  }
})
