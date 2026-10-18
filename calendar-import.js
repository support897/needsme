/* "Bring my calendar in" — the shared calendar import module.
   Design of record: IMPORT-DESIGN.md. Every app adopts this file
   unchanged; hosts change labels and tint only (IMPORT-ADOPTION.md).

   Parser: vendored ical.js 1.5.0 UMD (vendor/ical/, MPL-2.0) — the proven
   RFC 5545 engine (Mozilla). This file is the thin house layer:
   parse -> plan (pure, testable) -> apply (registry + counts).

   Fences (from the design): read-only against the source; imported
   data is the user's own (Law B); re-import dedupes, never doubles,
   never overwrites; repeats map live ONLY when the host's repeat
   model can say them truthfully — everything else expands. */
(function (root) {
  "use strict";
  var ICALRef = null;
  if (typeof ICAL !== "undefined") ICALRef = ICAL;
  else if (typeof require !== "undefined") { try { var m = require("./vendor/ical/ical.min.js"); ICALRef = (m && m.default) || m; } catch (e) { ICALRef = null; } }

  var DAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
  var BYDAY_NUM = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };

  function pad(n) { return (n < 10 ? "0" : "") + n; }
  function keyOf(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
  function timeOf(d) { return pad(d.getHours()) + ":" + pad(d.getMinutes()); }
  function hashStr(s) { var h = 5381; for (var i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0; return (h >>> 0).toString(36); }

  /* ---------- parse ---------- */
  function parseICS(text) {
    if (!ICALRef) return { calendarName: "", events: [], error: "parser missing" };
    var jcal;
    try { jcal = ICALRef.parse(String(text || "")); }
    catch (e) { return { calendarName: "", events: [], error: "not a calendar file" }; }
    var comp = new ICALRef.Component(jcal);
    // Register the file's own timezone definitions first (Apple/Outlook
    // exports lean on these; without them times land hours wrong).
    comp.getAllSubcomponents("vtimezone").forEach(function (vtz) {
      try {
        var tzid = vtz.getFirstPropertyValue("tzid");
        if (tzid) ICALRef.TimezoneService.register(tzid, new ICALRef.Timezone(vtz));
      } catch (e) { /* a broken vtimezone must not sink the import */ }
    });
    var calName = comp.getFirstPropertyValue("x-wr-calname") || "";
    var events = [];
    comp.getAllSubcomponents("vevent").forEach(function (ve) {
      try {
        var ev = new ICALRef.Event(ve);
        if (!ev.startDate) return;
        var rrule = null;
        var rr = ve.getFirstPropertyValue("rrule");
        if (rr) rrule = { freq: rr.freq || "", interval: rr.interval || 1, byday: (rr.parts && rr.parts.BYDAY) || [], until: !!rr.until, count: rr.count != null };
        var exdates = [];
        ve.getAllProperties("exdate").forEach(function (p) { p.getValues().forEach(function (v) { exdates.push(v.toJSDate ? keyOf(v.toJSDate()) : String(v)); }); });
        var recId = ve.getFirstPropertyValue("recurrence-id");
        events.push({
          uid: ev.uid || "", title: (ev.summary || "").trim(), notes: (ev.description || "").trim(),
          location: (ev.location || "").trim(),
          allDay: !!ev.startDate.isDate,
          // No DTEND and no DURATION in the source: the event has
          // NO end. ICAL reports end == start for these, and the
          // plan used to invent a 5-minute duration out of that
          // (ISSUE-020) — the flag keeps the truth instead.
          noEnd: !ve.getFirstProperty("dtend") && !ve.getFirstProperty("duration"),
          start: ev.startDate, end: ev.endDate || ev.startDate,
          rrule: rrule, exdates: exdates,
          recurrenceId: recId ? (recId.toJSDate ? keyOf(recId.toJSDate()) : String(recId)) : null,
          recurrenceSlot: recId && recId.toJSDate ? keyOf(recId.toJSDate()) + "|" + (recId.isDate ? "" : timeOf(recId.toJSDate())) : null,
          _ical: ev
        });
      } catch (e) { /* counted later as unparseable via raw count diff */ }
    });
    return { calendarName: calName, events: events };
  }

  /* ---------- repeat mapping: truth or expand ---------- */
  function mapRepeat(ev) {
    var r = ev.rrule;
    if (!r || ev.exdates.length || ev.recurrenceId) return null;
    if (r.until || r.count) return null;               // bounded -> expand
    if ((r.interval || 1) !== 1) return null;           // fortnightly etc -> expand
    var startDay = ev.start.toJSDate().getDay();
    if (r.freq === "DAILY") return "every day";
    if (r.freq === "WEEKLY") {
      var days = (r.byday || []).map(function (d) { return BYDAY_NUM[String(d).replace(/^[+-]?\d+/, "")]; }).filter(function (n) { return n != null; });
      if (!days.length) return "every week";
      if (days.length === 1) return days[0] === startDay ? "every week" : "every " + DAY_NAMES[days[0]];
      var sorted = days.slice().sort().join(",");
      if (sorted === "1,2,3,4,5") return "every weekday";
      if (sorted === "0,6") return "every weekend";
      return null;
    }
    return null; // MONTHLY / YEARLY / anything richer -> expand
  }

  /* ---------- expansion ---------- */
  function expandEvent(ev, winStart, winEnd, out) {
    var push = function (startDate, endDate, title) {
      var s = startDate.toJSDate(), e = endDate ? endDate.toJSDate() : s;
      if (s < winStart || s > winEnd) return;
      if (ev.allDay) {
        // One task per day the event touches.
        var d = new Date(s.getFullYear(), s.getMonth(), s.getDate());
        var last = new Date(e.getFullYear(), e.getMonth(), e.getDate());
        if (last > d) last.setDate(last.getDate() - 1); // DTEND for all-day is exclusive
        var guard = 0;
        while (d <= last && guard++ < 370) { out.push({ title: title, date: keyOf(d), time: null, durationMin: 30, allDay: true }); d.setDate(d.getDate() + 1); }
      } else {
        // The TRUE duration, uncapped: a multi-day event keeps
        // its whole span so the host can render it on every day
        // it touches (ISSUE-019 — the old 720 cap silently cut
        // a three-day event down to its first evening). A no-end
        // event (no DTEND/DURATION in the source) carries null:
        // no duration is ever invented for it (ISSUE-020 — the
        // old Math.max(5, ...) fabricated a 5-minute end).
        var mins = ev.noEnd ? null : Math.max(0, Math.round((e - s) / 60000));
        out.push({ title: title, date: keyOf(s), time: timeOf(s), durationMin: mins, allDay: false });
      }
    };
    if (!ev.rrule) { push(ev.start, ev.end, ev.title); return; }
    var it = ev._ical.iterator();
    var occ, guard = 0;
    var skip = {};
    ev.exdates.forEach(function (k) { skip[k] = true; });
    var skipSlots = ev._skipSlots || {};
    while ((occ = it.next()) && guard++ < 600) {
      var jsd = occ.toJSDate();
      if (jsd > winEnd) break;
      if (jsd < winStart) continue;
      if (skip[keyOf(jsd)]) continue;
      if (skipSlots[keyOf(jsd) + "|" + (occ.isDate ? "" : timeOf(jsd))]) continue;
      var endOcc = occ.clone(); endOcc.addDuration(ev._ical.duration);
      push(occ, endOcc, ev.title);
    }
  }

  /* ---------- the plan (pure) ---------- */
  function importKeyFor(sourceLabel, events) {
    var uids = events.map(function (e) { return e.uid; }).sort().join("|");
    return "imp-" + hashStr(sourceLabel + "::" + uids);
  }

  function planImport(parsed, existingTasks, opts) {
    opts = opts || {};
    var now = opts.now ? new Date(opts.now) : new Date();
    var winStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 30);
    var winEnd = new Date(now.getFullYear(), now.getMonth() + 12, now.getDate());
    var importKey = opts.importKey || importKeyFor(opts.sourceLabel || "calendar", parsed.events);
    var seen = {};
    (existingTasks || []).forEach(function (t) {
      if (t && t.importUid) seen[t.importKey + "|" + t.importUid + "|" + t.date + "|" + (t.time || "")] = true;
    });
    // Group overrides by uid; a series with overrides expands as a whole,
    // and the master's occurrence at each overridden slot is skipped.
    var overridden = {};
    var overrideSlots = {};
    parsed.events.forEach(function (e) {
      if (e.recurrenceId) {
        overridden[e.uid] = true;
        (overrideSlots[e.uid] = overrideSlots[e.uid] || {})[e.recurrenceSlot] = true;
      }
    });
    var plan = { importKey: importKey, add: [], liveRepeats: 0, expanded: 0, dupes: 0, skipped: [] };
    parsed.events.forEach(function (ev) {
      if (ev.recurrenceId) {
        // An override instance: it lands as its own single event.
        var singles = []; expandEvent({ _ical: ev._ical, rrule: null, start: ev.start, end: ev.end, allDay: ev.allDay, noEnd: ev.noEnd, exdates: [] }, winStart, winEnd, singles);
        singles.forEach(function (s) { addOne(plan, seen, ev, s, importKey, null); });
        return;
      }
      if (!ev.title) { plan.skipped.push({ title: "(no title)", why: "an event with no name" }); return; }
      var rep = (overridden[ev.uid] || opts.repeatModel === "none") ? null : mapRepeat(ev);
      if (rep) {
        var s0 = ev.start.toJSDate();
        // Same truth as expandEvent: real duration uncapped,
        // and null (never an invented 5) for a no-end event.
        var dur = ev.noEnd ? null : Math.max(0, Math.round((ev.end.toJSDate() - s0) / 60000));
        addOne(plan, seen, ev, { title: ev.title, date: keyOf(s0), time: ev.allDay ? null : timeOf(s0), durationMin: ev.allDay ? 30 : dur, allDay: ev.allDay }, importKey, rep);
        return;
      }
      var instances = [];
      ev._skipSlots = overrideSlots[ev.uid] || {};
      expandEvent(ev, winStart, winEnd, instances);
      if (!instances.length && !ev.rrule) plan.skipped.push({ title: ev.title, why: "outside the import window" });
      instances.forEach(function (s) { addOne(plan, seen, ev, s, importKey, null); });
      if (instances.length > 1 || ev.rrule) plan.expanded += instances.length;
    });
    return plan;
  }

  function addOne(plan, seen, ev, s, importKey, repeat) {
    var key = importKey + "|" + ev.uid + "|" + s.date + "|" + (s.time || "");
    if (seen[key]) { plan.dupes++; return; }
    seen[key] = true;
    plan.add.push({
      title: s.title, date: s.date, time: s.time, durationMin: s.durationMin,
      repeat: repeat || null, notes: ev.notes || "", location: ev.location || "",
      importUid: ev.uid, importKey: importKey, _live: !!repeat
    });
    if (repeat) plan.liveRepeats++;
  }

  /* ---------- apply (host commits through its own save) ---------- */
  function applyImport(state, plan, sourceLabel, toTask) {
    var added = 0;
    plan.add.forEach(function (shape) {
      state.tasks.push(toTask(shape));
      added++;
    });
    // The registry records imports that BROUGHT EVENTS IN. An empty
    // apply (all dupes, or a plan from a file that read as nothing)
    // writes no row — provenance stays truthful.
    if (added > 0) {
      state.imports = Array.isArray(state.imports) ? state.imports : [];
      state.imports.push({ key: plan.importKey, source: sourceLabel || "calendar", at: new Date().toISOString(), count: added });
    }
    return { added: added, liveRepeats: plan.liveRepeats, expanded: plan.expanded, dupes: plan.dupes, skipped: plan.skipped.length };
  }

  /* ---------- instant stamping (host seam) ---------- */
  // The plan speaks in the importing browser's LOCAL wall time
  // (date + "HH:MM"): that is the truth the parser proved, for UTC
  // ("Z"), TZID and floating times alike. A host that stores the
  // event as an instant must stamp it with THIS browser's real
  // offset for that date, read from the Date itself (so DST is
  // honoured) — never a hardcoded offset. A hardcoded stamp
  // silently moves every event imported from a browser in any
  // other zone: a 10:00Z event imported on a UTC browser and
  // stamped "+10:00" is stored as 00:00Z, and every viewer (and
  // every reminder) inherits the wrong hour. (ISSUE-008.)
  function localStamp(date, time) {
    var t = time || "09:00";
    var d = new Date(date + "T" + t + ":00");
    if (isNaN(d.getTime())) return date + "T" + t + ":00";
    var off = -d.getTimezoneOffset(); // minutes east of UTC, this date
    var sign = off < 0 ? "-" : "+";
    var abs = Math.abs(off);
    return date + "T" + t + ":00" + sign + pad(Math.floor(abs / 60)) + ":" + pad(abs % 60);
  }

  var CI = { parseICS: parseICS, planImport: planImport, applyImport: applyImport, importKeyFor: importKeyFor, mapRepeat: mapRepeat, localStamp: localStamp, _keyOf: keyOf };
  if (typeof module !== "undefined" && module.exports) module.exports = CI;
  root.CI = CI;
})(typeof window !== "undefined" ? window : globalThis);
