__precompile__(false)

module TidierErrors

using AbbreviatedStackTraces
using PromptingTools
using Pkg
using InteractiveUtils: clipboard
import REPL

export aicopy

function REPL.repl_display_error(errio::IO, @nospecialize errval)
    # this will be set to true if types in the stacktrace are truncated
    limit_types_flag = Ref(false)
    # this will be set to false if frames in the stacktrace are not hidden
    hide_internal_frames_flag = Ref(true)

    errio = IOContext(errio, :stacktrace_types_limited => limit_types_flag, :compacttrace => hide_internal_frames_flag)
    Base.invokelatest(Base.display_error, errio, errval)
    if limit_types_flag[] || hide_internal_frames_flag[]
        limit_types_flag[] && print(errio, "Some type information was truncated. ")
        hide_internal_frames_flag[] && print(errio, "Some frames were hidden. ")
        print(errio, "Next steps: \n  - Use `show(err)` to see complete trace\n  - Use `aicopy(err)` to copy error with context to clipboard. \n  - Use `ai(err)` to send error with context directly to LLM using PromptingTools.jl")
        println(errio)
    end
    return nothing
end

function get_context_for_llm()
    proj = Pkg.project()
    repl_history = Base.active_repl.mistate.current_mode.hist.history

    if length(repl_history) > 10
        repl_history = repl_history[end-10:end]
    end

    llm_context = """
        I'm using the Tidier packages in julia and I encountered an error.

        I'm using the following packages: $(keys(proj.dependencies)).

        Here is my REPL history: $(repl_history)

        I currently have the following objects in my workspace:
        $(names(Main))

        The error I got when I ran the code: $(repl_history[end-1]) was:
    """

    request = """

        Please reply with a short solution to the error or ask for clarification if you need more information.
        """

    return (llm_context, request)
end

function aicopy(err)
    try
        llm_context, request = get_context_for_llm()
        clipboard(llm_context * string(err) * request)
        println("Error with context copied to clipboard. Examine the contents before sending to an LLM if your project contains sensitive information.")
    catch e
        println("Failed to copy error with context to clipboard: ", e)
    end
end

function ai(err)
    llm_context, request = get_context_for_llm()
    aigenerate(llm_context * string(err) * request)
end
end
