import type { CampaignConfig } from './campaign-config'

function luminance(hex: string): number {
  const channels = [1, 3, 5].map((start) => {
    const value = Number.parseInt(hex.slice(start, start + 2), 16) / 255
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
  })
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
}

export function campaignContrast(foreground: string, background: string): number {
  const a = luminance(foreground)
  const b = luminance(background)
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
}

/** Header copy sits on the theme background rather than the cream cards. */
export function campaignHeaderSecondary(appearance: CampaignConfig['appearance']): string {
  return campaignContrast(appearance.headerText, appearance.background) >
    campaignContrast(appearance.smallText, appearance.background)
    ? appearance.headerText
    : appearance.smallText
}
