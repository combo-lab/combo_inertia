# Changelog

## Unreleased

## v0.4.0

- Add new required option - `:endpoint` to `Combo.Inertia.SSR`. It is for starting multiple SSR supervisors
- Change cookie name from `XSRF-TOKEN` to `CSRF-TOKEN`, and you should configure Axios like:

```javascript
import axios from "axios"

axios.defaults.xsrfCookieName = "CSRF-TOKEN"
axios.defaults.xsrfHeaderName = "X-CSRF-TOKEN"
```

## v0.3.0

Make it work with combo v0.5.0.

## v0.2.0

### remove `:prefix` and `:suffix` attr from `<Inertia.HTML.inertia_title>` component

It's easy to add prefix and suffix into inner_block, like:

```ceex
<.inertia_title>
  {assigns[:page_title] || "Home"} · MyApp
</.inertia_title>
```

Hence, these two attrs seems to unnecessary.

### change the fallback version as `"not-detected"`

Previously, it was `"1"`, which wasn't descriptive.
