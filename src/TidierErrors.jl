__precompile__(false)

module TidierErrors

using AbbreviatedStackTraces
import Base: RefValue, devnull
using PromptingTools
using Pkg
using Preferences
using InteractiveUtils: clipboard
using REPL.TerminalMenus
import REPL

export aicopy, ai, aisetup, errordisplaysetup

function Base.show_backtrace(io::IO, t::Vector)
    if haskey(io, :last_shown_line_infos)
        empty!(io[:last_shown_line_infos])
    end

    hide_internal_frames_flag = get(io, :compacttrace, nothing)
    if hide_internal_frames_flag isa RefValue{Bool}
        hide_internal_frames = hide_internal_frames_flag[]
        hide_internal_frames_flag[] = false # in case of early return
    else
        hide_internal_frames = false
    end

    hide_stacktrace = get(io, :hidetrace, false)

    if hide_stacktrace
        return
    end

    # t is a pre-processed backtrace (ref #12856)
    if t isa Vector{Any}
        filtered = t
    else
        filtered = AbbreviatedStackTraces.process_backtrace(t)
    end
    isempty(filtered) && return

    if length(filtered) == 1 && StackTraces.is_top_level_frame(filtered[1][1])
        f = filtered[1][1]::StackFrame
        if f.line == 0 && f.file === Symbol("")
            # don't show a single top-level frame with no location info
            return
        end
    end

    # restore
    if hide_internal_frames_flag isa RefValue{Bool}
        hide_internal_frames_flag[] = hide_internal_frames
    end

    if length(filtered) > AbbreviatedStackTraces.BIG_STACKTRACE_SIZE
        AbbreviatedStackTraces.show_reduced_backtrace(IOContext(io, :backtrace => true), filtered)
        return
    else
        try
            invokelatest(update_stackframes_callback[], filtered)
        catch
        end

        # process_backtrace returns a Vector{Tuple{Frame, Int}}
        if hide_internal_frames || parse(Bool, get(ENV, "JULIA_STACKTRACE_ABBREVIATED", "false"))
            AbbreviatedStackTraces.show_compact_backtrace(io, filtered; print_linebreaks=AbbreviatedStackTraces.stacktrace_linebreaks())
        else
            AbbreviatedStackTraces.show_full_backtrace(io, filtered; print_linebreaks=AbbreviatedStackTraces.stacktrace_linebreaks())
        end
    end
    return
end

function REPL.repl_display_error(errio::IO, @nospecialize errval)
    # this will be set to true if types in the stacktrace are truncated
    limit_types_flag = Ref(false)
    # this will be set to false if frames in the stacktrace are not hidden
    hide_internal_frames_flag = Ref(true)
    # this will be set to true if the entire stacktrace should be hidden
    hide_stacktrace_flag = get_stacktrace_show() == "None"
    # if false, no error will show at all
    show_error = get_error_show() == "Show Error Message"
    action = get_action()

    if show_error
        errio = IOContext(errio,
            :stacktrace_types_limited => limit_types_flag,
            :compacttrace => hide_internal_frames_flag,
            :hidetrace => hide_stacktrace_flag
        )

        Base.invokelatest(Base.display_error, errio, errval)
        if limit_types_flag[] || hide_internal_frames_flag[]
            limit_types_flag[] && print(errio, "Some type information was truncated. ")
            hide_internal_frames_flag[] && print(errio, "Some frames were hidden. ")
            get_followup_pref() == "Yes" && print(errio, "Next steps: \n  - Use `show(err)` to see complete trace\n  - Use `aicopy(err)` to copy error with context to clipboard. \n  - Use `ai(err)` to send error with context directly to LLM using PromptingTools.jl")
            println(errio)
        end
    end

    if action == "Copy to error with context to clipboard"
        aicopy(errval)
    elseif action == "Send error to LLM"
        msg = ai(errval)
        display(msg)
    end

    return nothing
end

function get_context_for_llm()
    proj = Pkg.project()
    repl_history = Base.active_repl.mistate.current_mode.hist.history

    # trim to the most recent 10 entries
    if length(repl_history) > 10
        repl_history = repl_history[end-10:end]
    end

    # the code that caused the error would have been the second last entry in the history - the last is the al/aicopy command
    llm_context = """
        I'm using julia and I encountered an error.

        I'm using the following packages: $(keys(proj.dependencies)).

        I currently have the following objects in my workspace:
        $(names(Main))

        Here is my REPL history: $(repl_history)

        The error I got when I ran that code was:
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
    msg = aigenerate(get_schema(), llm_context * string(err) * request; model=get_model())
    return msg
end

function aisetup()
    schema = "openai"
    provider = request("Which LLM Provider would you like to use?", RadioMenu(["OpenAI", "Ollama"]))
    if provider == 1
        println("Enter your OpenAI API key:")
        api_key = readline()
        model = nothing
        PromptingTools.OPENAI_API_KEY = api_key
        @info "You can set the environment variable OPENAI_API_KEY to avoid entering it every time."
    elseif provider == 2
        schema = "ollama"
        api_key = nothing
        println("Enter the name of the Ollama model:")
        model = readline()
    end

    @set_preferences!(
        "tidiererrors_llm_schema" => schema,
        "tidiererrors_llm_api_key" => api_key,
        "tidiererrors_llm_model" => model)

    return nothing
end

function errordisplaysetup()
    stack_options = ["Summary", "Full", "None"]
    stacktraces = request("How much detail do you want in your stack traces?", RadioMenu(stack_options))

    error_message_show = ["Show Error Message", "Do not show Error Message"]
    errors = request("Show error messages?", RadioMenu(error_message_show))

    followup_functions = ["Yes", "No"]
    followups = request("Show followup functions in errors (`show(err)`, `ai(err)`, etc)?", RadioMenu(followup_functions))

    actions = ["Do nothing", "Copy to error with context to clipboard", "Send error to LLM"]
    default_action = request("Default action for errors?", RadioMenu(actions))

    @set_preferences!(
        "tidiererrors_stacktraces" => stack_options[stacktraces],
        "tidiererrors_errors" => error_message_show[errors],
        "tidiererrors_followups" => followup_functions[followups],
        "tidiererrors_default_action" => actions[default_action])
end

function get_schema()
    schema = @load_preference("tidiererrors_llm_schema")
    return schema == "openai" ? PromptingTools.OpenAISchema() : PromptingTools.OllamaSchema()
end

function get_api_key()
    api_key = @load_preference("tidiererrors_llm_api_key")
    return api_key
end

function get_model()
    model = @load_preference("tidiererrors_llm_model")
    return model
end

function get_followup_pref()
    return @load_preference("tidiererrors_followups")
end

function get_stacktrace_show()
    return @load_preference("tidiererrors_stacktraces")
end

function get_default_action()
    return @load_preference("tidiererrors_default_action")
end

function get_error_show()
    return @load_preference("tidiererrors_errors")
end

function get_action()
    return @load_preference("tidiererrors_default_action")
end

end
