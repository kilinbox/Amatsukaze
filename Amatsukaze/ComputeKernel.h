/**
* Amatsukaze AVX Compute Kernel
* Copyright (c) 2017-2019 Nekopanda
*
* This software is released under the MIT License.
* http://opensource.org/licenses/mit-license.php
*/

#pragma once

// CPU機能の確認 (全アーキテクチャ共通)
bool IsAVXAvailable();
bool IsAVX2Available();

#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
// x86/x86_64 専用: AVX/AVX2 SIMD ヘッダーと関数宣言
#include <immintrin.h>

// 関数宣言
__m128 hsum5_256_ps(__m256 x);
float CalcCorrelation5x5_AVX(const float* k, const float* Y, int x, int y, int w, float* pavg);
float CalcCorrelation5x5_AVX2(const float* k, const float* Y, int x, int y, int w, float* pavg);
void removeLogoLineAVX2(float *dst, const float *src, const int srcStride, const float *logoAY, const float *logoBY, const int logowidth, const float maxv, const float fade);
#endif //#if defined(__x86_64__) || ...
