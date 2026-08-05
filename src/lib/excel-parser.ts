/**
 * Helper for reading and parsing Excel (.xlsx, .xls) files dynamically.
 */

export interface ExcelRow {
  [key: string]: any
}

export async function parseExcelFile(file: File): Promise<ExcelRow[]> {
  try {
    const XLSX = await import('xlsx')
    const buffer = await file.arrayBuffer()
    const workbook = XLSX.read(buffer, { type: 'array' })
    const firstSheetName = workbook.SheetNames[0]
    if (!firstSheetName) return []

    const worksheet = workbook.Sheets[firstSheetName]
    const json = XLSX.utils.sheet_to_json<ExcelRow>(worksheet, { defval: '' })
    return json
  } catch (error) {
    console.error('Failed to parse Excel file:', error)
    throw new Error('Could not parse Excel file. Please ensure it is a valid .xlsx or .xls file.')
  }
}
