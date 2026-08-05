declare module 'papaparse' {
  interface PapaResult<T = any> {
    data: T[]
    errors: Array<{ type: string; message: string }>
    meta: { fields?: string[]; aborted: boolean; truncated: boolean }
  }

  function parse<T = any>(input: string, config?: {
    header?: boolean
    skipEmptyLines?: boolean | 'greedy'
    transform?: (value: string) => string
    complete?: (results: PapaResult<T>) => void
  }): PapaResult<T>

  function unparse(data: any[], config?: any): string

  const Papa: { parse: typeof parse; unparse: typeof unparse }
  export default Papa
}
