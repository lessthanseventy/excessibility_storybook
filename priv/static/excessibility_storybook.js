// LiveView hooks for ExcessibilityStorybook.Inspector.
//
// Import into the storybook's JS (assets/js/storybook.js):
//
//   import { Hooks as A11yHooks } from "../../deps/excessibility_storybook/priv/static/excessibility_storybook.js"
//   window.storybook = { Hooks: { ...A11yHooks } }
//
// Every view reads the variation's iframe directly; it's served by the same
// storybook, so it's same-origin.

import {
  computeAccessibleName,
  getRole,
  isDisabled,
  isInaccessible,
  isSubtreeInaccessible,
} from "./vendor/dom-accessibility-api.mjs"

// Roles a screen reader announces as one stop, without reading inside them.
const LEAF_ROLES = new Set([
  "button", "link", "checkbox", "radio", "switch", "textbox", "searchbox",
  "combobox", "listbox", "slider", "spinbutton", "tab", "menuitem",
  "menuitemcheckbox", "menuitemradio", "option", "img", "heading", "progressbar",
])
const NAME_REQUIRED = new Set([...LEAF_ROLES].filter((r) => r !== "option"))
// Containers announced on the way in.
const CONTAINER_ROLES = new Set([
  "list", "table", "navigation", "form", "dialog", "alertdialog", "alert",
  "status", "region", "group", "radiogroup", "tablist", "menu", "main", "banner",
  "contentinfo", "complementary", "search",
])

const TEXT_SPACING = `* { line-height: 1.5 !important; letter-spacing: 0.12em !important;
  word-spacing: 0.16em !important; } p { margin-bottom: 2em !important; }`
const TEXT_200 = "html { font-size: 200% !important; }"

function states(el, role) {
  const out = []
  const aria = (a) => el.getAttribute(a)
  if (isDisabled(el)) out.push("dimmed")
  if (["checkbox", "radio", "switch", "menuitemcheckbox", "menuitemradio"].includes(role)) {
    const checked = aria("aria-checked") ?? (el.checked ? "true" : "false")
    out.push(checked === "true" ? "checked" : checked === "mixed" ? "half checked" : "not checked")
  }
  if (aria("aria-expanded")) out.push(aria("aria-expanded") === "true" ? "expanded" : "collapsed")
  if (aria("aria-pressed")) out.push(aria("aria-pressed") === "true" ? "pressed" : "not pressed")
  if (aria("aria-selected") === "true") out.push("selected")
  if (aria("aria-current") && aria("aria-current") !== "false") out.push("current")
  if (el.required || aria("aria-required") === "true") out.push("required")
  if (aria("aria-invalid") === "true") out.push("invalid entry")
  if (role === "textbox" || role === "searchbox") {
    if (el.value) out.push(el.value)
    else if (el.placeholder) out.push(`placeholder ${el.placeholder}`)
  }
  return out
}

function headingLevel(el) {
  return el.getAttribute("aria-level") || (/^H([1-6])$/.exec(el.tagName) || [])[1] || "2"
}

// Linearize the document roughly the way a screen reader's browse mode reads it.
function soundsLike(doc) {
  const lines = []
  let text = []
  const flushText = () => {
    const t = text.join(" ").replace(/\s+/g, " ").trim()
    if (t) lines.push({ text: t })
    text = []
  }

  const walk = (node) => {
    if (node.nodeType === Node.TEXT_NODE) {
      if (getComputedStyle(node.parentElement).visibility !== "visible") return
      return text.push(node.textContent)
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return
    const el = node
    if (["SCRIPT", "STYLE", "TEMPLATE"].includes(el.tagName)) return
    if (isSubtreeInaccessible(el)) return
    // visibility: hidden (a closed daisyUI modal, say) hides the element but a child
    // can opt back in with visibility: visible, so keep walking.
    if (isInaccessible(el)) return el.childNodes.forEach(walk)

    const role = getRole(el)

    if (LEAF_ROLES.has(role)) {
      flushText()
      const name = computeAccessibleName(el)
      const said =
        role === "heading"
          ? [`heading level ${headingLevel(el)}`, name]
          : [name, role === "img" ? "image" : role, ...states(el, role)]
      const missing = !name && NAME_REQUIRED.has(role)
      lines.push({
        text: said.filter(Boolean).join(", "),
        problem: missing ? `This ${role} has no accessible name.` : null,
      })
      return
    }

    if (CONTAINER_ROLES.has(role)) {
      flushText()
      const name = computeAccessibleName(el)
      let intro = [role, name].filter(Boolean).join(", ")
      if (role === "list") {
        intro += `, ${el.querySelectorAll(":scope > li, :scope > [role=listitem]").length} items`
      }
      if (role === "table") {
        const rows = el.querySelectorAll("tr").length
        const cols = el.querySelector("tr")?.children.length || 0
        intro += `, ${rows} rows, ${cols} columns`
      }
      lines.push({ text: intro })
      el.childNodes.forEach(walk)
      flushText()
      lines.push({ text: `out of ${role}` })
      return
    }

    el.childNodes.forEach(walk)
    if (getComputedStyle(el).display !== "inline") flushText()
  }

  walk(doc.body)
  flushText()
  return lines
}

const FOCUSABLE =
  'a[href], button, input, select, textarea, summary, iframe, [tabindex], [contenteditable=""], [contenteditable="true"]'

function tabOrder(doc) {
  const win = doc.defaultView
  const els = [...doc.querySelectorAll(FOCUSABLE)].filter(
    (el) =>
      el.tabIndex >= 0 &&
      !el.disabled &&
      el.getClientRects().length > 0 &&
      win.getComputedStyle(el).visibility !== "hidden" &&
      !(el.type === "hidden"),
  )
  const positive = els.filter((el) => el.tabIndex > 0).sort((a, b) => a.tabIndex - b.tabIndex)
  return [...positive, ...els.filter((el) => el.tabIndex === 0)]
}

function focusStyle(el) {
  const s = el.ownerDocument.defaultView.getComputedStyle(el)
  return `${s.outlineStyle} ${s.outlineWidth} ${s.outlineColor} ${s.boxShadow} ${s.borderColor} ${s.backgroundColor}`
}

function focusOrder(doc) {
  doc.querySelectorAll(".xsb-badge").forEach((b) => b.remove())
  const stops = tabOrder(doc)
  const counts = {}
  for (const el of stops) {
    const key = `${getRole(el)}|${computeAccessibleName(el)}`
    counts[key] = (counts[key] || 0) + 1
  }

  return stops.map((el, i) => {
    const role = getRole(el) || el.tagName.toLowerCase()
    const name = computeAccessibleName(el)
    const problems = []
    const twins = counts[`${getRole(el)}|${name}`]
    const plural = /(x|s)$/.test(role) ? `${role}es` : `${role}s`
    if (name && twins > 1) problems.push(`${twins} ${plural} share this name, so they can't be told apart out of context`)

    const before = focusStyle(el)
    el.focus({ focusVisible: true, preventScroll: true })
    const visible = focusStyle(el) !== before
    el.blur()

    if (!visible) problems.push("no visible change on focus")
    if (el.tabIndex > 0) problems.push(`tabindex=${el.tabIndex} jumps the natural order`)
    if (el.closest("[aria-hidden=true]")) problems.push("focusable but hidden from screen readers")
    if (!name) problems.push("no accessible name")

    const r = el.getBoundingClientRect()
    const win = doc.defaultView
    const badge = doc.createElement("span")
    badge.className = "xsb-badge"
    badge.setAttribute("aria-hidden", "true")
    badge.textContent = i + 1
    Object.assign(badge.style, {
      position: "absolute",
      left: `${r.left + win.scrollX - 10}px`,
      top: `${r.top + win.scrollY - 10}px`,
      zIndex: 2147483647,
      font: "bold 12px/20px system-ui",
      minWidth: "20px",
      height: "20px",
      textAlign: "center",
      borderRadius: "10px",
      color: "#fff",
      background: problems.length ? "#b00020" : "#1a5fb4",
      boxShadow: "0 0 0 2px #fff",
      pointerEvents: "none",
    })
    doc.body.appendChild(badge)

    return { text: `${i + 1}. ${[name, role].filter(Boolean).join(", ")}`, problem: problems.join("; ") || null }
  })
}

function stress(doc, mode, frame) {
  const style = doc.getElementById("xsb-style") || doc.head.appendChild(doc.createElement("style"))
  style.id = "xsb-style"
  style.textContent = mode === "text-spacing" ? TEXT_SPACING : mode === "text-200" ? TEXT_200 : ""

  const root = doc.documentElement
  const lines = []
  // Sideways scroll only fails reflow (WCAG 1.4.10), and data tables are exempt from it.
  if (mode === "reflow" && root.scrollWidth > root.clientWidth + 1) {
    const wideTable = [...doc.querySelectorAll("table")].some(
      (t) => t.scrollWidth > root.clientWidth,
    )
    lines.push({
      text: `Scrolls sideways: content is ${root.scrollWidth}px wide in a ${root.clientWidth}px frame.`,
      problem: wideTable ? null : "horizontal scrolling",
    })
    if (wideTable) lines.push({ text: "It's a data table, which WCAG exempts from reflow." })
  }

  const clipped = [...doc.body.querySelectorAll("*")].filter((el) => {
    const s = doc.defaultView.getComputedStyle(el)
    const hides = (o) => o === "hidden" || o === "clip"
    return (
      (hides(s.overflowX) && el.scrollWidth > el.clientWidth + 1) ||
      (hides(s.overflowY) && el.scrollHeight > el.clientHeight + 1)
    )
  })
  for (const el of clipped) {
    const what = computeAccessibleName(el) || el.textContent.trim().slice(0, 40)
    lines.push({ text: `Clipped: ${el.tagName.toLowerCase()} "${what}"`, problem: "content cut off" })
  }

  if (lines.length === 0) lines.push({ text: "Nothing clipped or scrolling sideways.", ok: true })
  frame.style.height = `${Math.min(root.scrollHeight + 4, 800)}px`
  return lines
}

function render(out, lines) {
  out.replaceChildren()
  if (lines.length === 0) return
  const list = out.ownerDocument.createElement("ol")
  for (const { text, problem, ok } of lines) {
    const li = out.ownerDocument.createElement("li")
    li.textContent = text
    if (ok) li.className = "xsb-ok"
    if (problem) {
      const p = out.ownerDocument.createElement("strong")
      p.textContent = ` Problem: ${problem}`
      li.appendChild(p)
      li.className = "xsb-problem"
    }
    list.appendChild(li)
  }
  out.appendChild(list)
}

const XsbFrame = {
  mounted() {
    this.onLoad = () => this.run()
    this.el.addEventListener("load", this.onLoad)
    if (this.el.contentDocument?.readyState === "complete") this.onLoad()
  },
  destroyed() {
    this.el.removeEventListener("load", this.onLoad)
  },
  run() {
    const doc = this.el.contentDocument
    if (!doc?.body) return
    const mode = this.el.dataset.mode
    const out = document.getElementById(this.el.dataset.output)
    let lines =
      mode === "sounds" ? soundsLike(doc) : mode === "focus" ? focusOrder(doc) : stress(doc, mode, this.el)
    if (mode === "sounds" || mode === "focus") {
      this.el.style.height = `${Math.min(doc.documentElement.scrollHeight + 24, 800)}px`
      if (lines.length === 0) {
        lines = [{ text: mode === "focus" ? "Nothing here can be reached with Tab." : "Nothing to read." }]
      }
    }
    if (out) render(out, lines)

    // A short summary, not the whole list, so a screen reader isn't made to re-read it.
    const status = document.getElementById(this.el.dataset.status)
    if (status) {
      const problems = lines.filter((l) => l.problem).length
      status.dataset.problems = problems
      status.textContent = `${lines.length} ${lines.length === 1 ? "line" : "lines"}, ${problems} ${problems === 1 ? "problem" : "problems"}.`
    }
  },
}

export const Hooks = { XsbFrame }
