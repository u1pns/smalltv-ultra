# Third-party notices

The firmware images published in this repository (`firmware/jailbreak/*.bin`, `firmware/v*/*.bin`) and the
resource packs (`firmware/v*/*.res`) contain third-party software and content. The authors' own code is
released under the MIT License (see [`LICENSE`](LICENSE)). This file lists every third-party component that is
compiled into the binaries, its license, and the notices those licenses require.

<!-- TODO: this list was built from the build of 2026-09-23 (framework 3.30102.0). Regenerate it for every new
     framework version. -->

## Summary

| Component | Version | In jailbreak image | In firmware image | License |
|---|---|---|---|---|
| ESP8266 Arduino core (`cores/esp8266`) and its libraries ESP8266WiFi, ESP8266WebServer, EEPROM, SPI, Ticker, LittleFS | 3.1.2 (PlatformIO `framework-arduinoespressif8266@3.30102.0`) | yes | yes | LGPL-2.1-or-later |
| ESP8266WebServer, **modified** (`Parsing-impl.h`, multipart parser) | 3.1.2 + local patch | yes | yes | LGPL-2.1-or-later |
| eboot bootloader | shipped with core 3.1.2 | yes | yes | BSD-3-Clause |
| uzlib (inside eboot) | shipped with core 3.1.2 | yes | yes | zlib |
| umm_malloc | shipped with core 3.1.2 | yes | yes | MIT |
| littlefs | shipped with core 3.1.2 | no | yes | BSD-3-Clause |
| lwIP | 2.1.3 (lwip2 glue 1.2-65-g06164fb) | yes | yes | BSD-3-Clause |
| `aes_unwrap` (from wpa_supplicant, Jouni Malinen) | shipped with core 3.1.2 | yes | yes | BSD (dual GPL-2.0/BSD, used under BSD) |
| Espressif ESP8266 NONOS SDK | 2.2.1-100-g876abc5 (`NONOSDK22x_190703`) | yes | yes | Espressif MIT License |
| newlib C library, libgcc, libstdc++ | xtensa-lx106 toolchain 2.100300.220621 (GCC 10.3) | yes | yes | newlib: BSD-style licenses; libgcc/libstdc++: GPL-3.0 with the GCC Runtime Library Exception |
| Hack typeface (rasterized into `f-*.jpf` inside `.res`) | 3.003, Hack-Bold | — | resource pack | MIT + Bitstream Vera License |

Weather icons (`i-*.jpi`) are drawn programmatically by the authors and are covered by the MIT License.

## LGPL-2.1: your rights and how to exercise them

The ESP8266 Arduino core and the libraries listed above are free software under the GNU Lesser General Public
License, version 2.1 or (at your option) any later version. They are statically linked into the firmware images.
A copy of the license is in [`LICENSE-LGPL-2.1.txt`](LICENSE-LGPL-2.1.txt).

You may modify the firmware for your own use and reverse engineer it to debug such modifications; nothing in this
repository's terms restricts that.

**Written offer (LGPL-2.1, section 6(c)).** For at least three years from the publication date of each firmware
image in this repository, the author will give any third party who asks, at no charge beyond the cost of physically
performing the distribution, the materials that section 6(a) of the LGPL-2.1 requires for that image: (1) the
complete source code of the LGPL-licensed library as used, including the author's modifications (the ESP8266 Arduino
core 3.1.2 with a patch to `libraries/ESP8266WebServer/src/Parsing-impl.h`, and one source file derived from the core,
`GpioSinOnda.cpp`); and (2) the application in object-file form, with the linker scripts and the exact link and
image-conversion commands, sufficient to relink the image against a modified version of the library. The source code
of the application itself is not part of this offer and is not distributed. Requests: open an issue in this
repository. See also [DISCLAIMER.md](DISCLAIMER.md).

## Weather and location data

Weather data by [Open-Meteo.com](https://open-meteo.com/), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). City search uses the Open-Meteo Geocoding API, based on
[GeoNames](https://www.geonames.org/) data, licensed under CC BY 4.0. The device downloads the data directly from
Open-Meteo using its owner's connection; the free Open-Meteo API is for non-commercial use only
(see <https://open-meteo.com/en/terms>). The firmware does not modify the data other than formatting it for display.
<!-- TODO: the device's web page does not show this attribution yet; add it next to the weather settings. -->

---

## License texts

### ESP8266 Arduino core — GNU LGPL 2.1

Copyright (c) the ESP8266 Arduino core contributors (see https://github.com/esp8266/Arduino).
Full text in `LICENSE-LGPL-2.1.txt`.

### eboot — BSD-3-Clause

```
Copyright (c) 2015 Ivan Grokhotkov
All rights reserved. 

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. The name of the authors may not be used to endorse or promote products
   derived from this software without specific prior written permission. 

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED 
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING 
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY 
OF SUCH DAMAGE.

Authors: Ivan Grokhotkov
```

### uzlib — zlib License

```
License
-------

uzlib - Deflate/Zlib-compatible LZ77 compression/decompression library

Copyright (c) 2003 Joergen Ibsen
Copyright (c) 1997-2014 Simon Tatham
Copyright (c) 2014-2020 Paul Sokolovsky

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must
   not claim that you wrote the original software. If you use this
   software in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original software.

```

### umm_malloc — MIT License

```
The MIT License (MIT)

Copyright (c) 2015 Ralph Hempel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

### littlefs — BSD-3-Clause

```
Copyright (c) 2022, The littlefs authors.  
Copyright (c) 2017, Arm Limited. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

-  Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this
   list of conditions and the following disclaimer in the documentation and/or
   other materials provided with the distribution.
-  Neither the name of ARM nor the names of its contributors may be used to
   endorse or promote products derived from this software without specific prior
   written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### lwIP — BSD-3-Clause

```
Copyright (c) 2001-2004 Swedish Institute of Computer Science.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

```

<!-- TODO: confirm the license of the lwip2 glue layer (d-a-v/esp82xx-nonos-linklayer). -->

### aes_unwrap (wpa_supplicant) — BSD

```
Copyright (c) 2003-2007, Jouni Malinen <j@w1.fi>
Distributed under the terms of the BSD license (the file is dual-licensed GPL-2.0 / BSD; BSD is used here).
```
<!-- TODO: paste the full BSD text referenced by that file. -->

### Espressif ESP8266 NONOS SDK — Espressif MIT License

```
ESPRESSIF MIT License

Copyright (c) 2015 <ESPRESSIF SYSTEMS (SHANGHAI) PTE LTD>

Permission is hereby granted for use on ESPRESSIF SYSTEMS ESP8266 only, in which case, it is free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### newlib, libgcc, libstdc++

newlib is distributed under a collection of BSD-style licenses; libgcc and libstdc++ are distributed under the
GNU GPL version 3 with the GCC Runtime Library Exception, which imposes no conditions on the firmware.
<!-- TODO: include the newlib COPYING.NEWLIB notices for the parts actually linked. -->

### Hack typeface — MIT License and Bitstream Vera License

The resource pack contains bitmap renderings of Hack Bold (https://github.com/source-foundry/Hack). The renderings
are not named "Bitstream" or "Vera".

```
The work in the Hack project is Copyright 2018 Source Foundry Authors and licensed under the MIT License

The work in the DejaVu project was committed to the public domain.

Bitstream Vera Sans Mono Copyright 2003 Bitstream Inc. and licensed under the Bitstream Vera License with Reserved Font Names "Bitstream" and "Vera"

### MIT License

Copyright (c) 2018 Source Foundry Authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### BITSTREAM VERA LICENSE

Copyright (c) 2003 by Bitstream, Inc. All Rights Reserved. Bitstream Vera is a trademark of Bitstream, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of the fonts accompanying this license ("Fonts") and associated documentation files (the "Font Software"), to reproduce and distribute the Font Software, including without limitation the rights to use, copy, merge, publish, distribute, and/or sell copies of the Font Software, and to permit persons to whom the Font Software is furnished to do so, subject to the following conditions:

The above copyright and trademark notices and this permission notice shall be included in all copies of one or more of the Font Software typefaces.

The Font Software may be modified, altered, or added to, and in particular the designs of glyphs or characters in the Fonts may be modified and additional glyphs or characters may be added to the Fonts, only if the fonts are renamed to names not containing either the words "Bitstream" or the word "Vera".

This License becomes null and void to the extent applicable to Fonts or Font Software that has been modified and is distributed under the "Bitstream Vera" names.

The Font Software may be sold as part of a larger software package but no copy of one or more of the Font Software typefaces may be sold by itself.

THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL BITSTREAM OR THE GNOME FOUNDATION BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.

Except as contained in this notice, the names of Gnome, the Gnome Foundation, and Bitstream Inc., shall not be used in advertising or otherwise to promote the sale, use or other dealings in this Font Software without prior written authorization from the Gnome Foundation or Bitstream Inc., respectively. For further information, contact: fonts at gnome dot org.
```
