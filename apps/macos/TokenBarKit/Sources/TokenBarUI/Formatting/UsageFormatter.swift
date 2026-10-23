import Foundation
import TokenBarCore

/// Turns usage values and dates into display strings.
///
/// All calculations use absolute dates and the injected calendar/time zone, never string math.
/// Countdowns are truncated, so they never claim more time than remains.
public struct UsageFormatter: Sendable {
    public var locale: Locale
    public var calendar: Calendar
    /// Where strings are looked up. Language follows the app's language, not `locale`
    /// (a Mac can run in English with a Brazilian region). Tests pass a specific `.lproj` bundle.
    let strings: Bundle

    public init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) {
        self.init(locale: locale, timeZone: timeZone, strings: .module)
    }

    init(locale: Locale, timeZone: TimeZone, strings: Bundle) {
        self.locale = locale
        self.strings = strings
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = locale
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// "17%", "<1%" for small non-zero usage, "–" when unknown. Rounds down, so 99.6% is not shown as full.
    public func percent(_ fraction: Double?) -> String {
        guard let fraction else { return "–" }
        if fraction > 0 && fraction < 0.01 { return "<1%" }
        let truncated = (fraction * 100).rounded(.down) / 100
        return truncated.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// Like ``percent(_:)`` without the percent sign, for example "17" or "<1". Used where several
    /// values share one unit, such as "15/12" in the menu bar.
    public func percentNumber(_ fraction: Double?) -> String {
        guard let fraction else { return "–" }
        if fraction > 0 && fraction < 0.01 { return "<1" }
        return Int((fraction * 100).rounded(.down)).formatted(.number.locale(locale))
    }

    /// Up to two units, for example "2h 50m" or "2d 14h". "<1m" below one minute.
    public func countdown(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(max(interval, 0) / 60)
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll

        guard totalMinutes > 0 else {
            return "<" + (formatter.string(from: DateComponents(minute: 1)) ?? "1m")
        }
        let days = totalMinutes / (24 * 60)
        let hours = totalMinutes / 60 % 24
        let minutes = totalMinutes % 60
        let components =
            days > 0
            ? DateComponents(day: days, hour: hours)
            : DateComponents(hour: hours, minute: minutes)
        return formatter.string(from: components) ?? ""
    }

    /// Spelled-out length of a window, for example "5 hours" or "7 days".
    public func duration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(interval, 0)) ?? ""
    }

    /// Describes when a limit resets.
    ///
    /// - Within 24 hours: "Resets at 19:10 (in 2h 50m)".
    /// - Later: "Resets in 2d 14h (Sat, Oct 25 at 07:00)".
    /// - Past: "Reset due, updating soon".
    public func resetDescription(_ resetsAt: Date?, now: Date) -> String? {
        guard let resetsAt else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        guard remaining > 0 else {
            return localized("Reset due, updating soon")
        }
        let countdown = countdown(remaining)
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if remaining < 24 * 60 * 60 {
            let time = resetsAt.formatted(style.hour().minute())
            return localized("Resets at \(time) (in \(countdown))")
        }
        let date = resetsAt.formatted(style.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        return localized("Resets in \(countdown) (\(date))")
    }

    /// Clock time only, for example "19:10" or "7:10 PM".
    public func time(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute())
    }

    /// Name of a limit, for example "Current session" or "Weekly · Opus".
    public func title(for limit: UsageLimit) -> String {
        let base =
            switch limit.window {
            case .session: localized("Current session")
            case .rolling(let length): localized("Rolling window (\(duration(length.timeInterval)))")
            case .daily: localized("Today")
            case .weekly: localized("Weekly")
            case .monthly: localized("Monthly")
            }
        guard let scope = limit.scope else { return base }
        return "\(base) · \(scope)"
    }

    /// One-word name of a limit for compact lists, for example "Session", "Week" or "5h".
    public func shortTitle(for limit: UsageLimit) -> String {
        let base =
            switch limit.window {
            case .session: localized("Session")
            case .rolling(let length): countdown(length.timeInterval)
            case .daily: localized("Today")
            case .weekly: localized("Week")
            case .monthly: localized("Month")
            }
        guard let scope = limit.scope else { return base }
        return "\(base) · \(scope)"
    }

    /// Spoken form of a usage value, for example "17% used".
    public func usedDescription(_ fraction: Double?) -> String {
        localized("\(percent(fraction)) used")
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: strings, locale: locale)
    }

    /// "Updated just now", "Updated 4m ago", or "Not updated yet".
    public func updatedDescription(_ date: Date?, now: Date) -> String {
        guard let date else {
            return localized("Not updated yet")
        }
        let age = now.timeIntervalSince(date)
        guard age >= 60 else {
            return localized("Updated just now")
        }
        let ago = countdown(age)
        return localized("Updated \(ago) ago")
    }
}
