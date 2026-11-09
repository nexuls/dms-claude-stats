import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "translations.js" as Tr

PluginComponent {
    id: root

    // i18n
    property string lang: (SessionData.locale || Qt.locale().name).split(/[_-]/)[0]
    function tr(key) {
        return Tr.tr(key, lang);
    }

    // Calendar week labels: Monday to Sunday (fixed order)
    property int refreshEpoch: 0
    readonly property var dayLabelsByLanguage: ({
        en: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
        fr: ["Lu", "Ma", "Me", "Je", "Ve", "Sa", "Di"],
        es: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]
    })
    property var dayLabels: dayLabelsByLanguage[lang] || dayLabelsByLanguage.en

    // Settings
    property int refreshInterval: (pluginData.refreshInterval || 2) * 60000
    property bool showPacing: pluginData.showPacing !== false
    property var customProfiles: pluginData.customProfiles || []
    // ring | ringOnly | dual | text
    property string pillStyle: pluginData.pillStyle || "ring"
    readonly property bool compact: (pluginData.popoutLayout || "compact") === "compact"
    property bool customProfilesRefreshPending: false

    // API usage data
    property string subscriptionType: ""
    property string rateLimitTier: ""
    property real fiveHourUtil: 0
    property string fiveHourReset: ""
    property real sevenDayUtil: 0
    property string sevenDayReset: ""
    property bool extraUsageEnabled: false
    // ok | missing | expired | rate_limited | stale ("" until the first script run)
    property string authState: ""

    // Weekly state
    property int weekMessages: 0
    property int weekSessions: 0
    property real weekTokens: 0

    // Monthly state
    property real monthTokens: 0

    // All-time state
    property int alltimeSessions: 0
    property int alltimeMessages: 0
    property string firstSession: ""

    // Daily breakdown (rolling 7 days, computed from JSONL files)
    property var dailyTokens: [0, 0, 0, 0, 0, 0, 0]

    // Estimated API cost (in USD)
    property real todayCost: 0
    property real weekCost: 0
    property real monthCost: 0
    property var dailyCosts: [0, 0, 0, 0, 0, 0, 0]
    property real usdEurRate: 0

    // Chart hover state
    property int hoveredDay: -1

    // [{ modelName, modelTokens }] for the current calendar week
    property var weekModels: []

    // Profile selector state
    property string selectedProfile: "all"
    property var profileData: ({})
    // Shape per profile: { weekTokens, monthTokens, todayCost, weekCost, monthCost,
    //   daily:[7], dailyCosts:[7], weekModels:[{modelName,modelTokens}],
    //   fiveHourUtil, sevenDayUtil, fiveHourReset, sevenDayReset }

    // First entry is always "all"; populated by the PROFILES output field.
    property var profileNames: ["all"]

    // currentPd is a single reactive snapshot of the selected profile's data object.
    // Re-evaluated whenever selectedProfile or profileData changes.
    // All display* properties derive from this — ensures consistent re-evaluation.
    property var currentPd: {
        void (selectedProfile);
        void (profileData);
        if (selectedProfile === "all")
            return null;
        return profileData[selectedProfile] || null;
    }

    // Computed display values — switch between aggregate and per-profile data.
    property string displaySubscriptionType: currentPd && currentPd.subscriptionType ? currentPd.subscriptionType : subscriptionType
    property string displayRateLimitTier: currentPd && currentPd.rateLimitTier ? currentPd.rateLimitTier : rateLimitTier
    property real displayFiveHourUtil: currentPd && currentPd.fiveHourUtil !== undefined ? currentPd.fiveHourUtil : fiveHourUtil
    property string displayFiveHourReset: currentPd && currentPd.fiveHourReset !== undefined ? currentPd.fiveHourReset : fiveHourReset
    property real displaySevenDayUtil: currentPd && currentPd.sevenDayUtil !== undefined ? currentPd.sevenDayUtil : sevenDayUtil
    property string displaySevenDayReset: currentPd && currentPd.sevenDayReset !== undefined ? currentPd.sevenDayReset : sevenDayReset
    property string displayAuthState: currentPd && currentPd.authState !== undefined ? currentPd.authState : authState
    // "" (not yet known) counts as fine so nothing flashes before the first run
    readonly property bool authOk: authState === "" || authState === "ok"
    readonly property bool displayAuthOk: displayAuthState === "" || displayAuthState === "ok"
    readonly property string displayAuthNotice: authNotice(displayAuthState)
    property real displayWeekTokens: currentPd && currentPd.weekTokens !== undefined ? currentPd.weekTokens : weekTokens
    property int displayWeekMessages: currentPd && currentPd.weekMessages !== undefined ? currentPd.weekMessages : weekMessages
    property int displayWeekSessions: currentPd && currentPd.weekSessions !== undefined ? currentPd.weekSessions : weekSessions
    property real displayMonthTokens: currentPd && currentPd.monthTokens !== undefined ? currentPd.monthTokens : monthTokens
    property real displayTodayCost: currentPd && currentPd.todayCost !== undefined ? currentPd.todayCost : todayCost
    property real displayWeekCost: currentPd && currentPd.weekCost !== undefined ? currentPd.weekCost : weekCost
    property real displayMonthCost: currentPd && currentPd.monthCost !== undefined ? currentPd.monthCost : monthCost
    property var displayDailyTokens: currentPd && currentPd.daily ? currentPd.daily : dailyTokens
    property var displayModels: currentPd ? (currentPd.weekModels || []) : weekModels
    readonly property real displayModelTotal: displayModels.reduce((sum, m) => sum + m.modelTokens, 0)

    // Per-profile daily tokens for chart overlay. Empty array when "all" selected.
    property var profileDailyTokens: currentPd && currentPd.daily ? currentPd.daily : []

    // No displayDailyCosts: the hovered-day readout always shows aggregate dailyCosts.

    property string displayFiveHourCountdown: {
        if (!displayFiveHourReset || !displayAuthOk)
            return "";
        var resetMs = new Date(displayFiveHourReset).getTime();
        var remaining = Math.max(0, resetMs - countdownNow);
        if (remaining <= 0)
            return tr("Resetting...");
        var hours = Math.floor(remaining / 3600000);
        var mins = Math.floor((remaining % 3600000) / 60000);
        return hours + "h " + (mins < 10 ? "0" : "") + mins + "m";
    }

    property string displaySevenDayCountdown: {
        if (!displaySevenDayReset || !displayAuthOk)
            return "";
        var resetMs = new Date(displaySevenDayReset).getTime();
        var remaining = Math.max(0, resetMs - countdownNow);
        if (remaining <= 0)
            return tr("Resetting...");
        var days = Math.floor(remaining / 86400000);
        var hours = Math.floor((remaining % 86400000) / 3600000);
        var mins = Math.floor((remaining % 3600000) / 60000);
        if (days > 0)
            return days + "d " + hours + "h " + (mins < 10 ? "0" : "") + mins + "m";
        return hours + "h " + (mins < 10 ? "0" : "") + mins + "m";
    }

    readonly property var unknownPace: ({
            timeFrac: 0,
            delta: 0,
            status: "unknown"
        })

    // Pacing: whether usage is ahead of (over) or behind (under) a linear burn
    // rate for the time window. Each touches countdownNow so it recomputes on
    // the 60s timer below.
    property var fiveHourPace: {
        void (countdownNow);
        return displayAuthOk ? paceInfo(displayFiveHourUtil, displayFiveHourReset, 18000000) : unknownPace;
    }
    property var sevenDayPace: {
        void (countdownNow);
        return displayAuthOk ? paceInfo(displaySevenDayUtil, displaySevenDayReset, 604800000) : unknownPace;
    }
    // Pills are not profile-scoped — derive from aggregate 5h values.
    property var pillFivePace: {
        void (countdownNow);
        return paceInfo(fiveHourUtil, fiveHourReset, 18000000);
    }
    // Whether the taskbar pill should show the over-pace arrow/color. Shared by
    // the horizontal and vertical pills so they never diverge.
    readonly property bool pillOverPace: showPacing && authOk && (pillFivePace.status === "over" || pillFivePace.status === "over_quota")

    // Today's index in the calendar week (0=Monday, 6=Sunday)
    property int todayIndex: {
        void (countdownNow);
        var dow = new Date().getDay(); // 0=Sunday, 6=Saturday
        return dow === 0 ? 6 : dow - 1;
    }

    // Derived
    property real maxDaily: Math.max.apply(null, dailyTokens) || 1
    property bool isLoading: true

    // Live countdown
    property real countdownNow: Date.now()

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = Date.now();
            var elapsed = now - root.countdownNow;
            root.countdownNow = now;
            // Large gap (>2min) indicates wake from sleep — force immediate refresh
            if (elapsed > 120000 && !usageProcess.running) {
                usageProcess.running = true;
            }
        }
    }

    // Script path via PluginService
    property string scriptPath: PluginService.getPluginPath("claudeStats") + "/get-claude-usage"

    popoutWidth: compact ? 380 : 420

    // --- Helpers ---

    function formatTokens(n) {
        if (n >= 1000000000)
            return (n / 1000000000).toFixed(1) + "B";
        if (n >= 1000000)
            return (n / 1000000).toFixed(1) + "M";
        if (n >= 1000)
            return (n / 1000).toFixed(1) + "K";
        return Math.round(n).toString();
    }

    function shortModelName(name) {
        if (!name || name.length === 0)
            return name;
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    function progressColor(pct, base) {
        if (pct > 80)
            return Theme.error;
        if (pct > 50)
            return Theme.warning;
        return base || Theme.primary;
    }

    function modelColor(index) {
        return [Theme.primary, Theme.secondary, Theme.tertiary][index] || Theme.outline;
    }

    function barHeight(tokens, full) {
        if (!(tokens > 0) || maxDaily <= 0)
            return 0;
        return Math.max(tokens / maxDaily * full, Theme.spacingXXS);
    }

    // Returns { timeFrac, delta, status } for a usage window.
    // status: over_quota | over | under | on | unknown
    function paceInfo(util, resetIso, windowMs) {
        util = util || 0;
        if (!resetIso)
            return util >= 100 ? {
                timeFrac: 1,
                delta: util,
                status: "over_quota"
            } : {
                timeFrac: 0,
                delta: 0,
                status: "unknown"
            };
        var resetMs = new Date(resetIso).getTime();
        if (isNaN(resetMs))
            return {
                timeFrac: 0,
                delta: 0,
                status: "unknown"
            };
        var remaining = resetMs - countdownNow;
        var timeFrac = (windowMs - remaining) / windowMs;
        if (timeFrac < 0)
            timeFrac = 0;
        else if (timeFrac > 1)
            timeFrac = 1;
        var delta = util - timeFrac * 100;
        var status;
        if (util >= 100)
            status = "over_quota";
        else if (delta >= 5)
            status = "over";
        else if (delta <= -5)
            status = "under";
        else
            status = "on";
        return {
            timeFrac: timeFrac,
            delta: delta,
            status: status
        };
    }

    function paceLabel(p) {
        if (!p)
            return "";
        if (p.status === "over_quota")
            return tr("Over quota");
        if (p.status === "over")
            return Math.round(p.delta) + "% " + tr("over pace");
        if (p.status === "under")
            return Math.round(-p.delta) + "% " + tr("under pace");
        if (p.status === "on")
            return tr("On pace");
        return "";
    }

    function paceColor(status) {
        if (status === "over_quota")
            return Theme.error;
        if (status === "over")
            return Theme.warning;
        return Theme.surfaceVariantText;
    }

    // Notice for a non-ok auth state; "" when there is nothing to report
    // (ok, not yet known, or an unrecognised value from a newer script).
    function authNotice(state) {
        switch (state) {
        case "missing":
            return tr("No Claude Code CLI login found. Run `claude /login` to see rate limits.");
        case "expired":
            return tr("Claude Code login expired. Run `claude` to refresh it.");
        case "rate_limited":
            return tr("The usage API is rate limiting requests. Showing the last known values.");
        case "stale":
            return tr("Could not reach the usage API. Showing the last known values.");
        default:
            return "";
        }
    }

    function formatCost(usd) {
        var useEur = lang === "fr" && usdEurRate > 0;
        var n = useEur ? usd * usdEurRate : usd;
        var sym = useEur ? "" : "$";
        var suffix = useEur ? " €" : "";
        if (n >= 1000)
            return sym + (n / 1000).toFixed(1) + "K" + suffix;
        if (n >= 100)
            return sym + Math.round(n) + suffix;
        if (n >= 10)
            return sym + n.toFixed(1) + suffix;
        return sym + n.toFixed(2) + suffix;
    }

    function formatTier(tier) {
        if (!tier || tier === "unknown")
            return "";
        if (tier.indexOf("max_20x") >= 0)
            return tr("Max") + " 20x";
        if (tier.indexOf("max_5x") >= 0)
            return tr("Max") + " 5x";
        if (tier.indexOf("max") >= 0)
            return tr("Max");
        if (tier.indexOf("pro") >= 0)
            return tr("Pro");
        if (tier.indexOf("free") >= 0)
            return tr("Free");
        if (tier.indexOf("team") >= 0)
            return tr("Team");
        if (tier.indexOf("enterprise") >= 0)
            return tr("Enterprise");
        return tier.replace(/_/g, " ").replace(/\b\w/g, function (c) {
            return c.toUpperCase();
        });
    }

    function formatSubscription(subType, tier) {
        var tierLabel = formatTier(tier);
        if (!subType || subType === "unknown")
            return tierLabel;
        // Normalize subscriptionType like "claude_pro" → "Pro", "claude_max" → "Max"
        var subLabel = subType.replace(/^claude[_-]?/i, "").replace(/_/g, " ").replace(/\b\w/g, function (c) {
            return c.toUpperCase();
        });
        // Prefer tier label if it adds info beyond subType
        if (tierLabel && tierLabel !== subLabel)
            return subLabel + " · " + tierLabel;
        return subLabel || tierLabel;
    }

    // Helper: parse "name:value,name:value,..." into profileData[name][field]
    // For numeric fields. Full object replacement ensures QML reactivity.
    function parseProfileSimple(val, field, isFloat) {
        var _pd = Object.assign({}, profileData);
        var entries = val.split(",");
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var colon = entry.indexOf(":");
            if (colon < 0)
                continue;
            var name = entry.substring(0, colon);
            var v = isFloat ? (parseFloat(entry.substring(colon + 1)) || 0) : (parseInt(entry.substring(colon + 1)) || 0);
            if (!_pd[name])
                _pd[name] = {};
            else
                _pd[name] = Object.assign({}, _pd[name]);
            _pd[name][field] = v;
        }
        return _pd;
    }

    // Uses indexOf(":") so ISO 8601 timestamps (which contain colons) are parsed correctly —
    // profile names never contain colons, so the first colon is always the name delimiter.
    // An empty value after ":" (e.g. "personal:") is stored as "" — means no data for that profile.
    function parseProfileString(val, field) {
        var _pd = Object.assign({}, profileData);
        var entries = val.split(",");
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var colon = entry.indexOf(":");
            if (colon < 0)
                continue;
            var name = entry.substring(0, colon);
            if (!_pd[name])
                _pd[name] = {};
            else
                _pd[name] = Object.assign({}, _pd[name]);
            _pd[name][field] = entry.substring(colon + 1);
        }
        return _pd;
    }

    function parseProfileBool(val, field) {
        var _pd = Object.assign({}, profileData);
        var entries = val.split(",");
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var colon = entry.indexOf(":");
            if (colon < 0)
                continue;
            var name = entry.substring(0, colon);
            if (!_pd[name])
                _pd[name] = {};
            else
                _pd[name] = Object.assign({}, _pd[name]);
            _pd[name][field] = entry.substring(colon + 1) === "true";
        }
        return _pd;
    }

    function parseLine(line) {
        var idx = line.indexOf("=");
        if (idx < 0)
            return;
        var key = line.substring(0, idx);
        var val = line.substring(idx + 1);

        switch (key) {
        case "SUBSCRIPTION_TYPE":
            subscriptionType = val;
            break;
        case "RATE_LIMIT_TIER":
            rateLimitTier = val;
            break;
        case "FIVE_HOUR_UTIL":
            fiveHourUtil = parseFloat(val) || 0;
            break;
        case "FIVE_HOUR_RESET":
            fiveHourReset = val;
            break;
        case "SEVEN_DAY_UTIL":
            sevenDayUtil = parseFloat(val) || 0;
            break;
        case "SEVEN_DAY_RESET":
            sevenDayReset = val;
            break;
        case "EXTRA_USAGE_ENABLED":
            extraUsageEnabled = (val === "true");
            break;
        case "AUTH_STATE":
            authState = val;
            break;
        case "WEEK_MESSAGES":
            weekMessages = parseInt(val) || 0;
            break;
        case "WEEK_SESSIONS":
            weekSessions = parseInt(val) || 0;
            break;
        case "WEEK_TOKENS":
            weekTokens = parseFloat(val) || 0;
            break;
        case "MONTH_TOKENS":
            monthTokens = parseFloat(val) || 0;
            break;
        case "ALLTIME_SESSIONS":
            alltimeSessions = parseInt(val) || 0;
            break;
        case "ALLTIME_MESSAGES":
            alltimeMessages = parseInt(val) || 0;
            break;
        case "FIRST_SESSION":
            firstSession = val;
            break;
        case "WEEK_MODELS":
            {
                var wms0 = [];
                var wmpairs = val.length > 0 ? val.split(",") : [];
                for (var wmi = 0; wmi < wmpairs.length; wmi++) {
                    var wmeq = wmpairs[wmi].indexOf("=");
                    if (wmeq >= 0)
                        wms0.push({
                            modelName: wmpairs[wmi].substring(0, wmeq),
                            modelTokens: parseInt(wmpairs[wmi].substring(wmeq + 1)) || 0
                        });
                }
                weekModels = wms0;
                break;
            }
        case "DAILY":
            var parts = val.split(",");
            var arr = [];
            for (var j = 0; j < 7; j++)
                arr.push(j < parts.length ? (parseFloat(parts[j]) || 0) : 0);
            dailyTokens = arr;
            break;
        case "TODAY_COST":
            todayCost = parseFloat(val) || 0;
            break;
        case "WEEK_COST":
            weekCost = parseFloat(val) || 0;
            break;
        case "MONTH_COST":
            monthCost = parseFloat(val) || 0;
            break;
        case "USD_EUR_RATE":
            usdEurRate = parseFloat(val) || 0;
            break;
        case "DAILY_COSTS":
            var cparts = val.split(",");
            var carr = [];
            for (var k = 0; k < 7; k++)
                carr.push(k < cparts.length ? (parseFloat(cparts[k]) || 0) : 0);
            dailyCosts = carr;
            break;
        case "PROFILES":
            {
                var profs = val.split(",");
                profileNames = ["all"].concat(profs);
                // Reset selectedProfile if it no longer exists in new profile list
                if (selectedProfile !== "all") {
                    var found = false;
                    for (var fi = 0; fi < profs.length; fi++)
                        if (profs[fi] === selectedProfile) {
                            found = true;
                            break;
                        }
                    if (!found)
                        selectedProfile = "all";
                }
                break;
            }
        case "PROFILE_WEEK_TOKENS":
            profileData = parseProfileSimple(val, "weekTokens", false);
            break;
        case "PROFILE_MONTH_TOKENS":
            profileData = parseProfileSimple(val, "monthTokens", false);
            break;
        case "PROFILE_WEEK_MESSAGES":
            profileData = parseProfileSimple(val, "weekMessages", false);
            break;
        case "PROFILE_WEEK_SESSIONS":
            profileData = parseProfileSimple(val, "weekSessions", false);
            break;
        case "PROFILE_TODAY_COST":
            profileData = parseProfileSimple(val, "todayCost", true);
            break;
        case "PROFILE_WEEK_COST":
            profileData = parseProfileSimple(val, "weekCost", true);
            break;
        case "PROFILE_MONTH_COST":
            profileData = parseProfileSimple(val, "monthCost", true);
            break;
        case "PROFILE_SUBSCRIPTION":
            profileData = parseProfileString(val, "subscriptionType");
            break;
        case "PROFILE_TIER":
            profileData = parseProfileString(val, "rateLimitTier");
            break;
        case "PROFILE_FIVE_HOUR_UTIL":
            profileData = parseProfileSimple(val, "fiveHourUtil", true);
            break;
        case "PROFILE_SEVEN_DAY_UTIL":
            profileData = parseProfileSimple(val, "sevenDayUtil", true);
            break;
        case "PROFILE_FIVE_HOUR_RESET":
            profileData = parseProfileString(val, "fiveHourReset");
            break;
        case "PROFILE_SEVEN_DAY_RESET":
            profileData = parseProfileString(val, "sevenDayReset");
            break;
        case "PROFILE_EXTRA_USAGE":
            profileData = parseProfileBool(val, "extraUsageEnabled");
            break;
        case "PROFILE_AUTH_STATE":
            profileData = parseProfileString(val, "authState");
            break;
        case "PROFILE_DAILY":
            {
                var _pd1 = Object.assign({}, profileData);
                var blocks1 = val.split("|");
                for (var bi1 = 0; bi1 < blocks1.length; bi1++) {
                    var blk1 = blocks1[bi1];
                    var c1 = blk1.indexOf(":");
                    if (c1 < 0)
                        continue;
                    var pname1 = blk1.substring(0, c1);
                    var csv1 = blk1.substring(c1 + 1);
                    if (!_pd1[pname1])
                        _pd1[pname1] = {};
                    else
                        _pd1[pname1] = Object.assign({}, _pd1[pname1]);
                    var parts1 = csv1.split(",");
                    var arr1 = [];
                    for (var di = 0; di < 7; di++)
                        arr1.push(di < parts1.length ? (parseFloat(parts1[di]) || 0) : 0);
                    _pd1[pname1].daily = arr1;
                }
                profileData = _pd1;
                break;
            }
        case "PROFILE_DAILY_COSTS":
            {
                var _pd2 = Object.assign({}, profileData);
                var blocks2 = val.split("|");
                for (var bi2 = 0; bi2 < blocks2.length; bi2++) {
                    var blk2 = blocks2[bi2];
                    var c2 = blk2.indexOf(":");
                    if (c2 < 0)
                        continue;
                    var pname2 = blk2.substring(0, c2);
                    var csv2 = blk2.substring(c2 + 1);
                    if (!_pd2[pname2])
                        _pd2[pname2] = {};
                    else
                        _pd2[pname2] = Object.assign({}, _pd2[pname2]);
                    var parts2 = csv2.split(",");
                    var arr2 = [];
                    for (var dci = 0; dci < 7; dci++)
                        arr2.push(dci < parts2.length ? (parseFloat(parts2[dci]) || 0) : 0);
                    _pd2[pname2].dailyCosts = arr2;
                }
                profileData = _pd2;
                break;
            }
        case "PROFILE_WEEK_MODELS":
            {
                var _pd3 = Object.assign({}, profileData);
                var blocks3 = val.split("|");
                for (var bi3 = 0; bi3 < blocks3.length; bi3++) {
                    var blk3 = blocks3[bi3];
                    var c3 = blk3.indexOf(":");
                    if (c3 < 0)
                        continue;
                    var pname3 = blk3.substring(0, c3);
                    var mcsv = blk3.substring(c3 + 1);
                    if (!_pd3[pname3])
                        _pd3[pname3] = {};
                    else
                        _pd3[pname3] = Object.assign({}, _pd3[pname3]);
                    var wms = [];
                    if (mcsv.length > 0) {
                        var mentries = mcsv.split(",");
                        for (var mi = 0; mi < mentries.length; mi++) {
                            var eq = mentries[mi].indexOf("=");
                            if (eq < 0)
                                continue;
                            wms.push({
                                modelName: mentries[mi].substring(0, eq),
                                modelTokens: parseInt(mentries[mi].substring(eq + 1)) || 0
                            });
                        }
                    }
                    _pd3[pname3].weekModels = wms;
                }
                profileData = _pd3;
                break;
            }
        }
    }

    // --- Data fetching ---

    // Pick up an added/removed profile now instead of waiting for the refresh timer
    onCustomProfilesChanged: {
        if (usageProcess.running)
            customProfilesRefreshPending = true;
        else
            usageProcess.running = true;
    }

    Process {
        id: usageProcess
        // Wrapped in `timeout` as a watchdog. The refresh timer below skips a tick
        // while `running` is true, so a single run that never exits (a hung
        // `claude --version`, a stalled curl/find) freezes the widget on stale
        // values until the plugin is reloaded. Killing the run lets onExited fire.
        command: ["timeout", "120", "bash", root.scriptPath].concat(root.customProfiles.filter(p => p && p.name && p.path).map(p => p.name + "=" + p.path))
        running: false

        stdout: SplitParser {
            onRead: data => root.parseLine(data.trim())
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.isLoading = false;
                root.refreshEpoch++;
            }
            if (root.customProfilesRefreshPending) {
                root.customProfilesRefreshPending = false;
                Qt.callLater(function() {
                    if (!usageProcess.running)
                        usageProcess.running = true;
                });
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!usageProcess.running)
                usageProcess.running = true;
        }
    }


    // --- Shared visuals ---

    component UsageRing: DRingGauge {
        id: ring

        property real percent: 0
        property color baseColor: Theme.primary
        property var pace: null

        value: Math.min(Math.max(percent, 0), 100) / 100
        ringColor: root.progressColor(percent, baseColor)

        // Linear-burn position: where usage would be at a steady rate
        Item {
            anchors.fill: parent
            visible: root.showPacing && ring.pace !== null && ring.pace.status !== "unknown"
            rotation: ring.pace ? Math.min(Math.max(ring.pace.timeFrac, 0), 1) * ring.spanAngle : 0

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -Theme.spacingXXS
                width: Theme.outlineWidthFocused
                height: ring.strokeWidth + Theme.spacingXXS * 2
                radius: width / 2
                color: Theme.surfaceText
            }
        }
    }

    component PillGauge: Item {
        id: gauge

        readonly property real stroke: Math.max(Theme.spacingXXS, root.iconSize / 8)

        width: root.iconSize
        height: root.iconSize
        visible: root.pillStyle !== "text"

        UsageRing {
            anchors.fill: parent
            strokeWidth: gauge.stroke
            percent: root.fiveHourUtil
        }

        UsageRing {
            anchors.centerIn: parent
            width: parent.width - (gauge.stroke + Theme.spacingXXS) * 2
            height: width
            visible: root.pillStyle === "dual"
            strokeWidth: gauge.stroke
            percent: root.sevenDayUtil
            baseColor: Theme.tertiary
        }
    }

    component PillLabel: StyledText {
        property bool stacked: false
        readonly property string fiveText: Math.round(root.fiveHourUtil) + "%" + (root.pillOverPace ? " ↑" : "")
        readonly property string sevenText: Math.round(root.sevenDayUtil) + "%"

        visible: root.pillStyle !== "ringOnly"
        text: {
            if (root.pillStyle !== "text")
                return fiveText;
            return stacked ? fiveText + "\n" + sevenText : "5h " + fiveText + " · 7d " + sevenText;
        }
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
        color: root.pillOverPace ? root.paceColor(root.pillFivePace.status) : Theme.surfaceText
    }

    component RateWindow: Row {
        id: rate

        property string label: ""
        property real percent: 0
        property var pace: null
        property string countdown: ""
        property color baseColor: Theme.primary
        property string extra: ""

        spacing: Theme.spacingM

        UsageRing {
            id: rateRing
            width: root.compact ? Theme.buttonHeightM : Theme.buttonHeightM + Theme.spacingXL
            height: width
            anchors.verticalCenter: parent.verticalCenter
            strokeWidth: root.compact ? Theme.spacingXS + Theme.spacingXXS : Theme.spacingS
            trackGap: Theme.spacingXXS
            percent: rate.percent
            pace: rate.pace
            baseColor: rate.baseColor

            StyledText {
                anchors.centerIn: parent
                text: Math.round(rate.percent) + "%"
                font.pixelSize: root.compact ? Theme.fontSizeMedium : Theme.fontSizeXLarge
                font.weight: Theme.fontWeightBold
                color: Theme.surfaceText
            }
        }

        Column {
            width: Math.max(0, rate.width - rateRing.width - rate.spacing)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXXS

            StyledText {
                width: parent.width
                text: rate.label
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            Row {
                width: parent.width
                spacing: Theme.spacingXXS
                visible: rate.countdown !== ""

                DIcon {
                    id: resetIcon
                    anchors.verticalCenter: parent.verticalCenter
                    name: "restart_alt"
                    size: Theme.iconSizeSmall
                    color: Theme.onSurfaceVariant
                }

                StyledText {
                    width: parent.width - resetIcon.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: rate.countdown
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            StyledText {
                width: parent.width
                text: root.paceLabel(rate.pace)
                visible: root.showPacing && text !== ""
                font.pixelSize: Theme.fontSizeSmall
                color: root.paceColor(rate.pace ? rate.pace.status : "")
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                text: rate.extra
                visible: text !== ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }
    }

    component TokenTile: DCard {
        id: tile

        property string label: ""
        property real tokens: 0
        property real cost: 0

        height: tileColumn.implicitHeight + pad * 2
        restRadius: Theme.cornerRadiusL

        Column {
            id: tileColumn
            width: parent.width
            spacing: Theme.spacingXXS

            StyledText {
                width: parent.width
                text: tile.label
                font.pixelSize: Theme.fontSizeSmall
                color: tile.mutedColor
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.formatTokens(tile.tokens)
                font.pixelSize: root.compact ? Theme.fontSizeLarge : Theme.fontSizeXLarge
                font.weight: Theme.fontWeightBold
                color: tile.contentColor
                elide: Text.ElideRight
            }

            // Kept in layout when hidden so all three tiles stay the same height
            StyledText {
                width: parent.width
                text: root.formatCost(tile.cost)
                opacity: tile.cost > 0 ? 1 : 0
                font.pixelSize: Theme.fontSizeSmall
                color: tile.mutedColor
                elide: Text.ElideRight
            }
        }
    }

    // --- Taskbar pills (show 5h utilization) ---

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            opacity: root.authOk ? 1 : 0.45

            PillGauge {
                anchors.verticalCenter: parent.verticalCenter
            }

            PillLabel {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            opacity: root.authOk ? 1 : 0.45

            PillGauge {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            PillLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                stacked: true
            }
        }
    }

    // --- Popout ---

    popoutContent: Component {
        PopoutComponent {
            headerText: root.tr("Claude Code Usage")
            detailsText: {
                var label = root.formatSubscription(root.displaySubscriptionType, root.displayRateLimitTier);
                return label ? root.tr("Subscription") + ": " + label : "";
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                // Hidden when there is only one real profile
                DFilterChips {
                    width: parent.width
                    visible: root.profileNames.length > 2
                    showCounts: false
                    model: root.profileNames.map(name => name === "all" ? root.tr("All") : name)
                    currentIndex: Math.max(0, root.profileNames.indexOf(root.selectedProfile))
                    // A click replaces the currentIndex binding, so it is restored by hand
                    onSelectionChanged: index => {
                        root.selectedProfile = root.profileNames[index] || "all";
                        currentIndex = Qt.binding(() => Math.max(0, root.profileNames.indexOf(root.selectedProfile)));
                    }
                }

                // Only when the rate limit numbers can't be trusted
                Rectangle {
                    width: parent.width
                    height: noticeRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadiusL
                    color: Theme.errorContainer
                    visible: root.displayAuthNotice !== ""

                    Row {
                        id: noticeRow
                        x: Theme.spacingM
                        y: Theme.spacingS
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingS

                        DIcon {
                            id: noticeIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: "warning"
                            size: Theme.iconSizeSmall
                            color: Theme.onErrorContainer
                        }

                        StyledText {
                            width: parent.width - noticeIcon.width - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.displayAuthNotice
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.onErrorContainer
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // --- Rate windows ---
                DCard {
                    width: parent.width
                    height: rateGrid.implicitHeight + pad * 2
                    restRadius: Theme.cornerRadiusL

                    Grid {
                        id: rateGrid

                        readonly property real cellWidth: root.compact ? (width - columnSpacing) / 2 : width

                        width: parent.width
                        columns: root.compact ? 2 : 1
                        columnSpacing: Theme.spacingM
                        rowSpacing: Theme.spacingM
                        opacity: root.displayAuthOk ? 1 : 0.45

                        RateWindow {
                            width: rateGrid.cellWidth
                            label: root.tr("5 hours")
                            percent: root.displayFiveHourUtil
                            pace: root.fiveHourPace
                            countdown: root.displayFiveHourCountdown
                        }

                        RateWindow {
                            width: rateGrid.cellWidth
                            label: root.tr("7 days")
                            percent: root.displaySevenDayUtil
                            pace: root.sevenDayPace
                            countdown: root.displaySevenDayCountdown
                            baseColor: Theme.tertiary
                            extra: {
                                if (root.compact)
                                    return "";
                                var parts = [];
                                if (root.displayWeekSessions > 0)
                                    parts.push(root.displayWeekSessions + " " + root.tr("sessions"));
                                if (root.displayWeekMessages > 0)
                                    parts.push(root.displayWeekMessages + " " + root.tr("msgs"));
                                return parts.join(" · ");
                            }
                        }
                    }
                }

                // --- Token consumption ---
                Row {
                    id: tokenRow

                    readonly property real tileWidth: (width - spacing * 2) / 3

                    width: parent.width
                    spacing: Theme.spacingS

                    TokenTile {
                        width: tokenRow.tileWidth
                        tone: "primary"
                        label: root.tr("Today")
                        tokens: root.displayDailyTokens[root.todayIndex]
                        cost: root.displayTodayCost
                    }

                    TokenTile {
                        width: tokenRow.tileWidth
                        tone: "secondary"
                        label: root.tr("Week")
                        tokens: root.displayWeekTokens
                        cost: root.displayWeekCost
                    }

                    TokenTile {
                        width: tokenRow.tileWidth
                        tone: "tertiary"
                        label: root.tr("Month")
                        tokens: root.displayMonthTokens
                        cost: root.displayMonthCost
                    }
                }

                // --- Daily activity ---
                DCard {
                    width: parent.width
                    height: activityColumn.implicitHeight + pad * 2
                    restRadius: Theme.cornerRadiusL

                    Column {
                        id: activityColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        Item {
                            width: parent.width
                            height: activityTitle.implicitHeight

                            StyledText {
                                id: activityTitle
                                text: root.tr("Daily Activity")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.primary
                            }

                            // Hovered day: total tokens, the selected profile's share, aggregate cost
                            StyledText {
                                anchors.right: parent.right
                                anchors.left: activityTitle.right
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideLeft
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.onSurfaceVariant
                                text: {
                                    var d = root.hoveredDay;
                                    if (d < 0 || !(root.dailyTokens[d] > 0))
                                        return "";
                                    var parts = [root.formatTokens(root.dailyTokens[d])];
                                    if (root.selectedProfile !== "all" && root.profileDailyTokens[d] > 0)
                                        parts.push(root.formatTokens(root.profileDailyTokens[d]) + " " + root.selectedProfile);
                                    if (root.dailyCosts[d] > 0)
                                        parts.push(root.formatCost(root.dailyCosts[d]));
                                    return parts.join(" · ");
                                }
                            }
                        }

                        Row {
                            id: chartRow
                            width: parent.width
                            height: root.compact ? Theme.buttonHeightM : Theme.buttonHeightM + Theme.spacingXL
                            spacing: Theme.spacingXS

                            Repeater {
                                model: 7

                                Item {
                                    id: day

                                    required property int index
                                    readonly property bool isToday: index === root.todayIndex
                                    readonly property bool highlighted: index === root.hoveredDay
                                    readonly property real barOpacity: root.hoveredDay >= 0 && !highlighted ? 0.4 : 1

                                    width: (chartRow.width - chartRow.spacing * 6) / 7
                                    height: chartRow.height

                                    Item {
                                        id: barArea
                                        anchors.top: parent.top
                                        anchors.bottom: dayLabel.top
                                        anchors.bottomMargin: Theme.spacingXXS
                                        width: parent.width

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.cornerRadiusXS
                                            color: Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover)
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: root.barHeight(root.dailyTokens[day.index], barArea.height)
                                            radius: Theme.cornerRadiusXS
                                            color: root.selectedProfile === "all" && day.isToday ? Theme.primary : root.selectedProfile === "all" ? Theme.primaryContainer : Theme.surfaceVariant
                                            opacity: day.barOpacity
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: root.barHeight(root.profileDailyTokens[day.index], barArea.height)
                                            visible: root.selectedProfile !== "all"
                                            radius: Theme.cornerRadiusXS
                                            color: Theme.primary
                                            opacity: day.barOpacity
                                        }
                                    }

                                    StyledText {
                                        id: dayLabel
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.dayLabels[day.index]
                                        font.pixelSize: Theme.fontSizeXSmall
                                        font.weight: day.isToday ? Theme.fontWeightBold : Theme.fontWeight
                                        color: day.isToday || day.highlighted ? Theme.primary : Theme.onSurfaceVariant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: root.dailyTokens[day.index] > 0
                                        onEntered: root.hoveredDay = day.index
                                        onExited: root.hoveredDay = -1
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Models this week: share bar with a legend ---
                DCard {
                    width: parent.width
                    height: modelColumn.implicitHeight + pad * 2
                    restRadius: Theme.cornerRadiusL
                    visible: root.displayModelTotal > 0

                    Column {
                        id: modelColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: root.tr("Models This Week")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Theme.fontWeightMedium
                            color: Theme.primary
                        }

                        Row {
                            id: modelBar
                            width: parent.width
                            height: Theme.spacingS
                            spacing: Theme.spacingXXS
                            clip: true

                            Repeater {
                                model: root.displayModels

                                Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: Math.max(Theme.spacingXXS, (modelBar.width - modelBar.spacing * (root.displayModels.length - 1)) * modelData.modelTokens / root.displayModelTotal)
                                    height: modelBar.height
                                    radius: height / 2
                                    color: root.modelColor(index)
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingM

                            Repeater {
                                model: root.displayModels

                                Row {
                                    required property var modelData
                                    required property int index

                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.spacingS
                                        height: width
                                        radius: width / 2
                                        color: root.modelColor(index)
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.shortModelName(modelData.modelName)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.formatTokens(modelData.modelTokens)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }

                // --- All-time footer (detailed layout) ---
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingXS
                    visible: !root.compact && root.selectedProfile === "all" && (root.alltimeSessions > 0 || root.alltimeMessages > 0)

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "calendar_today"
                        size: Theme.iconSizeSmall
                        color: Theme.onSurfaceVariant
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var parts = [];
                            if (root.firstSession && root.firstSession !== "unknown")
                                parts.push(root.tr("Since") + " " + root.firstSession);
                            parts.push(root.alltimeSessions + " " + root.tr("sessions"));
                            parts.push(root.alltimeMessages.toLocaleString() + " " + root.tr("msgs"));
                            return parts.join(" · ");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onSurfaceVariant
                    }
                }
            }
        }
    }
}
