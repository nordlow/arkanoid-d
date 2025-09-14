module sdl.log;

version(none) :

nothrow @nogc:

import core.stdc.stdarg : va_list;

extern(C):

enum SDL_LogCategory {
	SDL_LOG_CATEGORY_APPLICATION,
	SDL_LOG_CATEGORY_ERROR,
	SDL_LOG_CATEGORY_ASSERT,
	SDL_LOG_CATEGORY_SYSTEM,
	SDL_LOG_CATEGORY_AUDIO,
	SDL_LOG_CATEGORY_VIDEO,
	SDL_LOG_CATEGORY_RENDER,
	SDL_LOG_CATEGORY_INPUT,
	SDL_LOG_CATEGORY_TEST,
	SDL_LOG_CATEGORY_GPU,
	SDL_LOG_CATEGORY_RESERVED2,
	SDL_LOG_CATEGORY_RESERVED3,
	SDL_LOG_CATEGORY_RESERVED4,
	SDL_LOG_CATEGORY_RESERVED5,
	SDL_LOG_CATEGORY_RESERVED6,
	SDL_LOG_CATEGORY_RESERVED7,
	SDL_LOG_CATEGORY_RESERVED8,
	SDL_LOG_CATEGORY_RESERVED9,
	SDL_LOG_CATEGORY_RESERVED10,
	SDL_LOG_CATEGORY_CUSTOM
}

enum SDL_LogPriority {
	SDL_LOG_PRIORITY_INVALID,
	SDL_LOG_PRIORITY_TRACE,
	SDL_LOG_PRIORITY_VERBOSE,
	SDL_LOG_PRIORITY_DEBUG,
	SDL_LOG_PRIORITY_INFO,
	SDL_LOG_PRIORITY_WARN,
	SDL_LOG_PRIORITY_ERROR,
	SDL_LOG_PRIORITY_CRITICAL,
	SDL_LOG_PRIORITY_COUNT
}

alias SDL_LogOutputFunction = void function(void* userdata, SDL_LogCategory category, SDL_LogPriority priority, const(char)* message);

void SDL_SetLogPriorities(SDL_LogPriority priority);
void SDL_SetLogPriority(SDL_LogCategory category, SDL_LogPriority priority);
SDL_LogPriority SDL_GetLogPriority(SDL_LogCategory category);
void SDL_ResetLogPriorities();
bool SDL_SetLogPriorityPrefix(SDL_LogPriority priority, const(char)* prefix);
void SDL_Log(const(char)* fmt, ...);
void SDL_LogTrace(SDL_LogCategory category, const(char)* fmt, ...);
void SDL_LogVerbose(SDL_LogCategory category, const(char)* fmt, ...);
void SDL_LogDebug(SDL_LogCategory category, const(char)* fmt, ...);
void SDL_LogInfo(SDL_LogCategory category, const(char)* fmt, ...);
void SDL_LogWarn(SDL_LogCategory category, const(char)* fmt, ...);
void SDL_LogError(SDL_LogCategory category, const(char)* fmt, ...);
void SDL_LogMessage(SDL_LogCategory category, SDL_LogPriority priority, const(char)* fmt, ...);
void SDL_LogMessageV(SDL_LogCategory category, SDL_LogPriority priority, const(char)* fmt, va_list ap);
void SDL_GetLogOutputFunction(SDL_LogOutputFunction* callback, void** userdata);
void SDL_SetLogOutputFunction(SDL_LogOutputFunction callback, void* userdata);
