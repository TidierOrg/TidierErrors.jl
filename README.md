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

using Tidier, TidierErrors
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
julia> using Tidier, TidierErrors

julia> df = DataFrame(id = [string('A' + i ÷ 26, 'A' + i % 26) for i in 0:9],
                               groups = [i % 2 == 0 ? "aa" : "bb" for i in 1:10],
                               value = repeat(1:5, 2),
                               percent = 0.1:0.1:1.0);

julia> @chain df @mutate(x = value + 3) @filter(y > 5)
ERROR: ArgumentError: column name "y" not found in the data frame; existing most similar names are: "x" and "id"
Some frames were hidden. Next steps:
  - Use `show(err)` to see complete trace
  - Use `aicopy(err)` to copy error with context to clipboard.
  - Use `ai(err)` to send error with context directly to LLM using PromptingTools.jl

julia> ai(err)
[ Info: Tokens: 1330 in 11.0 seconds
PromptingTools.AIMessage("`@filter(y > 5)` fails because the dataframe has **no column named `y`** – you created a new column called **`x`** in the previous `@mutate`.
Use the correct column name in the filter (or create the column first):

```julia
# add the column
df2 = @chain df @mutate(x = value + 3)

# now filter on that column
df2 = @chain df2 @filter(x > 5)

# or do it in one chain
df3 = @chain df @mutate(x = value + 3) @filter(x > 5)
#```

That will return all rows where the new column `x` exceeds 5. If you intended to filter on another existing column, replace `x` with its correct name.")
```
