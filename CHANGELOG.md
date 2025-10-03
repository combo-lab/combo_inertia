# Changelog

## Unreleased

### remove `:prefix` and `:suffix` attr from `<Inertia.HTML.inertia_title>` component

It's easy to add prefix and suffix into inner_block, like:

```ceex
<.inertia_title>
  {assigns[:page_title] || "Home"} · MyApp
</.inertia_title>
```

Hence, these two attrs seems to unnecessary.
