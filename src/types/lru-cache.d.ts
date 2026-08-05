declare module 'lru-cache' {
  export type OnEviction<K, V> = (
    key: K,
    value: V,
    reason: EvictionReason
  ) => void

  export type EvictionReason = 'lru' | 'ttl' | 'size' | 'dispose' | 'custom'

  export interface LRUCacheOptions<K = any, V = any> {
    max: number
    maxSize?: number
    sizeCalculation?: (value: V, key: K) => number
    ttl?: number
    ttlResolution?: number
    ttlAutopurge?: boolean
    allowStale?: boolean
    updateAgeOnGet?: boolean
    updateAgeOnHas?: boolean
    fetchMethod?: (key: K, staleValue: V | undefined) => V | Promise<V>
    dispose?: (key: K, value: V) => void
    disposeAfter?: OnEviction<K, V>
  }

  export class LRUCache<K = any, V = any> {
    constructor(options: LRUCacheOptions<K, V>)
    get(key: K): V | undefined
    set(key: K, value: V, ttl?: number): this
    delete(key: K): boolean
    has(key: K): boolean
    clear(): this
    keys(): IterableIterator<K>
    values(): IterableIterator<V>
    entries(): IterableIterator<[K, V]>
    get size(): number
    forEach(
      fn: (value: V, key: K, cache: LRUCache<K, V>) => void,
      thisp?: any
    ): void
    rforEach(
      fn: (value: V, key: K, cache: LRUCache<K, V>) => void,
      thisp?: any
    ): void
    pop(): { key: K; value: V } | undefined
  }

  export default LRUCache
}
