/**
* Amtasukaze Compile Target
* Copyright (c) 2017 Nekopanda
*
* This software is released under the MIT License.
* http://opensource.org/licenses/mit-license.php
*/
#define _USE_MATH_DEFINES
// avisynthにリンクしているので
#define AVS_LINKAGE_DLLIMPORT
#include "AmatsukazeCLI.hpp"

HMODULE g_DllHandle;

extern "C" __declspec(dllexport) const char* __stdcall AvisynthPluginInit3(IScriptEnvironment* env, const AVS_Linkage* const vectors) {
	// 直接リンクしているのでvectorsを格納する必要はない

	// FFMPEGライブラリ初期化
	av_register_all();

	env->AddFunction("AMTSource", "s", av::CreateAMTSource, 0);
	env->AddFunction("AMTEraseLogo", "cs[thresh]f", logo::AMTEraseLogo::Create, 0);

	return "Amatsukaze plugin";
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpReserved) {
	if (dwReason == DLL_PROCESS_ATTACH) g_DllHandle = hModule;
	return TRUE;
}
