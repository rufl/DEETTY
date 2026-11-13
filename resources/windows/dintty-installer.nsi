Unicode true
ManifestDPIAware true
RequestExecutionLevel user

!ifndef DINTTY_PAYLOAD
  !error "DINTTY_PAYLOAD must name the portable payload directory"
!endif
!ifndef DINTTY_OUTPUT
  !error "DINTTY_OUTPUT must name the installer output"
!endif
!ifndef PRODUCT_VERSION
  !error "PRODUCT_VERSION must be defined"
!endif
!ifndef PRODUCT_VERSION_NUMERIC
  !error "PRODUCT_VERSION_NUMERIC must be defined"
!endif
!ifndef PACKAGE_REVISION
  !error "PACKAGE_REVISION must be defined"
!endif
!ifndef ESTIMATED_SIZE_KIB
  !error "ESTIMATED_SIZE_KIB must be defined"
!endif

!include "MUI2.nsh"

!define PRODUCT_NAME "DINTTY"
!define PRODUCT_PUBLISHER "DINTTY contributors"
!define PRODUCT_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\DINTTY"
!define NOCTED_APP_KEY "Software\Classes\Applications\nocted.exe"
!define NOCTED_PROGID_KEY "Software\Classes\NoctEd.Text"

Name "${PRODUCT_NAME}"
OutFile "${DINTTY_OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\DINTTY"
SetCompressor /SOLID lzma
SetDatablockOptimize on
CRCCheck on
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "${PRODUCT_VERSION_NUMERIC}"
VIAddVersionKey /LANG=1033 "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=1033 "FileVersion" "${PRODUCT_VERSION}.${PACKAGE_REVISION}"
VIAddVersionKey /LANG=1033 "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey /LANG=1033 "FileDescription" "DINTTY per-user installer"
VIAddVersionKey /LANG=1033 "LegalCopyright" "DINTTY contributors"

!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${DINTTY_PAYLOAD}/LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  SetShellVarContext current
FunctionEnd

Function un.onInit
  SetShellVarContext current
FunctionEnd

Section "DINTTY and NoctEd (required)" SEC_CORE
  SectionIn RO
  SetShellVarContext current
  SetOverwrite on
  SetOutPath "$INSTDIR"
  File /oname=dintty.exe "${DINTTY_PAYLOAD}/dintty.exe"
  File /oname=nocted.exe "${DINTTY_PAYLOAD}/nocted.exe"
  File /oname=LICENSE "${DINTTY_PAYLOAD}/LICENSE"
  File /oname=THIRD_PARTY_NOTICES.md "${DINTTY_PAYLOAD}/THIRD_PARTY_NOTICES.md"
  File /oname=UNICODE-LICENSE.txt "${DINTTY_PAYLOAD}/UNICODE-LICENSE.txt"
  File /oname=WINDOWS.md "${DINTTY_PAYLOAD}/WINDOWS.md"
  File /oname=WINDOWS-SMOKE.ps1 "${DINTTY_PAYLOAD}/WINDOWS-SMOKE.ps1"
  File /oname=BUILD-INFO.txt "${DINTTY_PAYLOAD}/BUILD-INFO.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\DINTTY"
  CreateShortcut "$SMPROGRAMS\DINTTY\DINTTY.lnk" "$INSTDIR\dintty.exe" "" "$INSTDIR\dintty.exe" 0
  CreateShortcut "$SMPROGRAMS\DINTTY\NoctEd.lnk" "$INSTDIR\nocted.exe" "" "$INSTDIR\nocted.exe" 0
  CreateShortcut "$SMPROGRAMS\DINTTY\Uninstall DINTTY.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayVersion" "${PRODUCT_VERSION}.${PACKAGE_REVISION}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayIcon" "$INSTDIR\dintty.exe"
  WriteRegStr HKCU "${PRODUCT_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "${PRODUCT_KEY}" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegDWORD HKCU "${PRODUCT_KEY}" "EstimatedSize" ${ESTIMATED_SIZE_KIB}
  WriteRegDWORD HKCU "${PRODUCT_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${PRODUCT_KEY}" "NoRepair" 1

  WriteRegStr HKCU "${NOCTED_APP_KEY}\shell\open\command" "" '$\"$INSTDIR\nocted.exe$\" $\"%1$\"'
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".txt" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".c" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".h" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".cc" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".cpp" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".cxx" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".hh" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".hpp" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".py" ""
  WriteRegStr HKCU "${NOCTED_APP_KEY}\SupportedTypes" ".json" ""
  WriteRegStr HKCU "${NOCTED_PROGID_KEY}" "" "NoctEd text document"
  WriteRegStr HKCU "${NOCTED_PROGID_KEY}\DefaultIcon" "" "$INSTDIR\nocted.exe,0"
  WriteRegStr HKCU "${NOCTED_PROGID_KEY}\shell\open\command" "" '$\"$INSTDIR\nocted.exe$\" $\"%1$\"'

  WriteRegStr HKCU "Software\Classes\.txt\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.c\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.h\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.cc\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.cpp\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.cxx\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.hh\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.hpp\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.py\OpenWithProgids" "NoctEd.Text" ""
  WriteRegStr HKCU "Software\Classes\.json\OpenWithProgids" "NoctEd.Text" ""
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd

Section /o "Desktop shortcut for DINTTY" SEC_DESKTOP_DINTTY
  SetShellVarContext current
  CreateShortcut "$DESKTOP\DINTTY.lnk" "$INSTDIR\dintty.exe" "" "$INSTDIR\dintty.exe" 0
SectionEnd

Section /o "Desktop shortcut for NoctEd" SEC_DESKTOP_NOCTED
  SetShellVarContext current
  CreateShortcut "$DESKTOP\NoctEd.lnk" "$INSTDIR\nocted.exe" "" "$INSTDIR\nocted.exe" 0
SectionEnd

LangString DESC_SEC_CORE ${LANG_ENGLISH} "Native DINTTY terminal, NoctEd editor, Start Menu shortcuts, and reversible Open-With registration."
LangString DESC_SEC_DESKTOP_DINTTY ${LANG_ENGLISH} "Create an optional DINTTY shortcut on this user's desktop."
LangString DESC_SEC_DESKTOP_NOCTED ${LANG_ENGLISH} "Create an optional NoctEd shortcut on this user's desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CORE} $(DESC_SEC_CORE)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP_DINTTY} $(DESC_SEC_DESKTOP_DINTTY)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP_NOCTED} $(DESC_SEC_DESKTOP_NOCTED)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  SetShellVarContext current
  Delete "$DESKTOP\DINTTY.lnk"
  Delete "$DESKTOP\NoctEd.lnk"
  Delete "$SMPROGRAMS\DINTTY\DINTTY.lnk"
  Delete "$SMPROGRAMS\DINTTY\NoctEd.lnk"
  Delete "$SMPROGRAMS\DINTTY\Uninstall DINTTY.lnk"
  RMDir "$SMPROGRAMS\DINTTY"

  DeleteRegValue HKCU "Software\Classes\.txt\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.c\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.h\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.cc\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.cpp\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.cxx\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.hh\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.hpp\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.py\OpenWithProgids" "NoctEd.Text"
  DeleteRegValue HKCU "Software\Classes\.json\OpenWithProgids" "NoctEd.Text"
  DeleteRegKey /ifempty HKCU "Software\Classes\.txt\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.c\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.h\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.cc\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.cpp\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.cxx\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.hh\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.hpp\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.py\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "Software\Classes\.json\OpenWithProgids"
  DeleteRegKey HKCU "${NOCTED_APP_KEY}"
  DeleteRegKey HKCU "${NOCTED_PROGID_KEY}"
  DeleteRegKey HKCU "${PRODUCT_KEY}"

  Delete "$INSTDIR\dintty.exe"
  Delete "$INSTDIR\nocted.exe"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.md"
  Delete "$INSTDIR\UNICODE-LICENSE.txt"
  Delete "$INSTDIR\WINDOWS.md"
  Delete "$INSTDIR\WINDOWS-SMOKE.ps1"
  Delete "$INSTDIR\BUILD-INFO.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd
