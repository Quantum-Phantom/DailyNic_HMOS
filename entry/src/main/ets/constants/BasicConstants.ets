import { i18n } from "@kit.LocalizationKit";

export const FULL_TIME_FORMAT: Intl.DateTimeFormatOptions = {
  year: "numeric",
  month: 'numeric',
  day: 'numeric',
  hour: '2-digit',
  minute: 'numeric',
  second: 'numeric',
  hourCycle: i18n.System.is24HourClock() ? 'h23' : 'h12'
};