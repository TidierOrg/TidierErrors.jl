# TidierErrors

[![Build Status](https://github.com/TidierOrg/TidierErrors.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/TidierOrg/TidierErrors.jl/actions/workflows/CI.yml?query=branch%3Amain)

## TidierErrors.jl

Make Julia errors easier to read—and easier to fix.

**TidierErrors** shortens lengthy stack traces in the REPL and streamlines optional next steps to:
- copy the full error (plus useful context) to your clipboard, or
- send the error directly to an LLM (OpenAI or Ollama) via [PromptingTools.jl](https://github.com/JuliaMLUtils/PromptingTools.jl) to get a quick suggestion.

It also ships a quick setup helper for configuring your preferred LLM provider and model.

---

## Features

- **Cleaner errors in the REPL.** Uses `AbbreviatedStackTraces` to hide internal frames and truncate verbose types. Optionally hide stack traces and/or error messages completely.
- **Actionable next steps.** After an error you’ll see:
  - `show(err)` to reveal the complete trace
  - `aicopy(err)` to copy the error **with context** to your clipboard
  - `ai(err)` to send the error **with context** to an LLM and print the reply
- **One-time setup.** `aisetup()` guides you through selecting OpenAI or Ollama and stores your choices with `Preferences.jl`. Use `errordisplaysetup()` to change error display settings.
- **Take actions automatically on error.** Copy error with context or send the whole thing to the LLM automatically.

---

## Installation

```julia
pkg> using Pkg; Pkg.add(url="https://github.com/TidierOrg/TidierErrors.jl")

julia> using TidierErrors
julia> aisetup()
Which LLM Provider would you like to use?
   OpenAI
 > Ollama
Enter the name of the Ollama model:
gpt-oss:20B
 ```

## Example
Heres a quick demonstration
 ```
julia> using TidierErrors

julia> sum([])
ERROR: MethodError: no method matching zero(::Type{Any})
This error has been manually thrown, explicitly, so the method may exist but be intentionally marked as unimplemented.

Closest candidates are:
  zero(::Type{Union{Missing, T}}) where T
   @ Base missing.jl:105
  zero(::Type{Union{}}, Any...)
   @ Base number.jl:310
  zero(::Type{Missing})
   @ Base missing.jl:104
  ...

Stacktrace:
      ⋮ internal @ Base, Unknown
 [13] sum(a::Vector{Any})
    @ Base ./reducedim.jl:982
Some frames were hidden. Use `show(err)` to see complete trace.

julia> ai(err)
[ Info: Tokens: 1983 in 37.6 seconds
  Short fix

  sum([]) is an empty array of type Any. Julia can’t find a default zero(Any) so
  it throws

  MethodError: no method matching zero(::Type{Any})

  Replace that call with one of the following:

  sum(Int[])          # → 0
  sum(Float64[])      # → 0.0
  sum([], init=0)    # ← gives zero of the same type you specify in init

  If you’re summing values that come from a groupby/summarise pipeline, let
  summarise handle the aggregation instead of calling sum([]) directly.

  ────────────────────────────────────────────────────────────────────────────────

  Why it happened

  [] defaults to Vector{Any}, and zero(Any) is intentionally undefined. Providing
  an explicit element type or an init value removes the ambiguity.
```
