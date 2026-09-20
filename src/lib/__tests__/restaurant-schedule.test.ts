import test, { describe } from 'node:test'
import assert from 'node:assert/strict'
import {
  parseTimeStringToMinutes,
  isManuallyPausedToday,
  checkStoreOperatingStatus,
} from '../restaurant-schedule'

describe('Restaurant Schedule & Operating Status Utilities', () => {
  describe('parseTimeStringToMinutes', () => {
    test('parses 12-hour AM times correctly', () => {
      assert.equal(parseTimeStringToMinutes('12:00 AM'), 0)
      assert.equal(parseTimeStringToMinutes('06:30 AM'), 6 * 60 + 30)
      assert.equal(parseTimeStringToMinutes('11:45 AM'), 11 * 60 + 45)
    })

    test('parses 12-hour PM times correctly', () => {
      assert.equal(parseTimeStringToMinutes('12:00 PM'), 12 * 60)
      assert.equal(parseTimeStringToMinutes('01:30 PM'), 13 * 60 + 30)
      assert.equal(parseTimeStringToMinutes('10:15 PM'), 22 * 60 + 15)
      assert.equal(parseTimeStringToMinutes('11:59 PM'), 23 * 60 + 59)
    })

    test('parses 24-hour times without AM/PM', () => {
      assert.equal(parseTimeStringToMinutes('07:00'), 420)
      assert.equal(parseTimeStringToMinutes('18:45'), 18 * 60 + 45)
      assert.equal(parseTimeStringToMinutes('23:30'), 23 * 60 + 30)
    })

    test('handles whitespace and lowercase strings', () => {
      assert.equal(parseTimeStringToMinutes('  09:15 am  '), 9 * 60 + 15)
      assert.equal(parseTimeStringToMinutes('8:00 pm'), 20 * 60)
    })

    test('returns null for invalid inputs', () => {
      assert.equal(parseTimeStringToMinutes(''), null)
      assert.equal(parseTimeStringToMinutes('   '), null)
      assert.equal(parseTimeStringToMinutes('invalid'), null)
      assert.equal(parseTimeStringToMinutes('ab:cd'), null)
      assert.equal(parseTimeStringToMinutes(null as unknown as string), null)
    })
  })

  describe('isManuallyPausedToday', () => {
    test('returns false when restaurant is open', () => {
      assert.equal(isManuallyPausedToday({ isOpen: true }), false)
      assert.equal(isManuallyPausedToday({ isOpen: 'true' as any }), false)
    })

    test('returns true when updatedAt is missing and isOpen is false', () => {
      assert.equal(isManuallyPausedToday({ isOpen: false, updatedAt: null }), true)
    })

    test('returns false when paused on a previous day (auto-reset on new day)', () => {
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)

      const result = isManuallyPausedToday({
        isOpen: false,
        openTime: '10:00 AM',
        updatedAt: yesterday.toISOString(),
      })
      assert.equal(result, false)
    })

    test('returns true when paused today after open time', () => {
      const todayAfterOpen = new Date()
      // Paused today at current time
      const result = isManuallyPausedToday({
        isOpen: false,
        openTime: '12:00 AM',
        updatedAt: todayAfterOpen.toISOString(),
      })
      assert.equal(result, true)
    })
  })

  describe('checkStoreOperatingStatus', () => {
    test('returns open for undefined restaurant', () => {
      const status = checkStoreOperatingStatus(undefined)
      assert.equal(status.isOpen, true)
      assert.equal(status.isClosedBySchedule, false)
      assert.equal(status.isClosedByOwner, false)
      assert.equal(status.formattedScheduleStr, 'Open for Orders')
    })

    test('returns open when no schedule is set and isOpen is true', () => {
      const status = checkStoreOperatingStatus({
        isOpen: true,
        openTime: '',
        closeTime: '',
      })
      assert.equal(status.isOpen, true)
      assert.equal(status.formattedScheduleStr, 'Open for Orders')
    })

    test('returns 24-hour store as continuously open', () => {
      const status = checkStoreOperatingStatus({
        isOpen: true,
        openTime: '00:00',
        closeTime: '23:59',
      })
      assert.equal(status.isOpen, true)
      assert.equal(status.isClosedBySchedule, false)
    })

    test('respects manual pause by owner during active hours', () => {
      const now = new Date()
      const status = checkStoreOperatingStatus({
        isOpen: false,
        openTime: '12:00 AM',
        closeTime: '11:59 PM',
        updatedAt: now.toISOString(),
      })
      assert.equal(status.isOpen, false)
      assert.equal(status.isClosedByOwner, true)
      assert.equal(status.formattedScheduleStr, 'Temporarily Paused by Store Owner')
    })
  })
})
