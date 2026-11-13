Unicode true
ManifestDPIAware true
RequestExecutionLevel user

!ifndef DEETTY_PAYLOAD
  !error "DEETTY_PAYLOAD must name the portable payload directory"
!endif
!ifndef DEETTY_OUTPUT
  !error "DEETTY_OUTPUT must name the installer output"
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

!define PRODUCT_NAME "DEETTY"
!define PRODUCT_PUBLISHER "DEETTY contributors"
!define PRODUCT_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\DEETTY"
!define NOCTED_APP_KEY "Software\Classes\Applications\nocted.exe"
!define NOCTED_PROGID_KEY "Software\Classes\NoctEd.Text"

Name "${PRODUCT_NAME}"
OutFile "${DEETTY_OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\DEETTY"
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
VIAddVersionKey /LANG=1033 "FileDescription" "DEETTY per-user installer"
VIAddVersionKey /LANG=1033 "LegalCopyright" "DEETTY contributors"

!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${DEETTY_PAYLOAD}/LICENSE"
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

Section "DEETTY and NoctEd (required)" SEC_CORE
  SectionIn RO
  SetShellVarContext current
  SetOverwrite on
  SetOutPath "$INSTDIR"
  File /oname=deetty.exe "${DEETTY_PAYLOAD}/deetty.exe"
  File /oname=nocted.exe "${DEETTY_PAYLOAD}/nocted.exe"
  File /oname=LICENSE "${DEETTY_PAYLOAD}/LICENSE"
  File /oname=THIRD_PARTY_NOTICES.md "${DEETTY_PAYLOAD}/THIRD_PARTY_NOTICES.md"
  File /oname=UNICODE-LICENSE.txt "${DEETTY_PAYLOAD}/UNICODE-LICENSE.txt"
  File /oname=WINDOWS.md "${DEETTY_PAYLOAD}/WINDOWS.md"
  File /oname=WINDOWS-SMOKE.ps1 "${DEETTY_PAYLOAD}/WINDOWS-SMOKE.ps1"
  File /oname=BUILD-INFO.txt "${DEETTY_PAYLOAD}/BUILD-INFO.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\DEETTY"
  CreateShortcut "$SMPROGRAMS\DEETTY\DEETTY.lnk" "$INSTDIR\deetty.exe" "" "$INSTDIR\deetty.exe" 0
  CreateShortcut "$SMPROGRAMS\DEETTY\NoctEd.lnk" "$INSTDIR\nocted.exe" "" "$INSTDIR\nocted.exe" 0
  CreateShortcut "$SMPROGRAMS\DEETTY\Uninstall DEETTY.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayVersion" "${PRODUCT_VERSION}.${PACKAGE_REVISION}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayIcon" "$INSTDIR\deetty.exe"
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

Section /o "Desktop shortcut for DEETTY" SEC_DESKTOP_DEETTY
  SetShellVarContext current
  CreateShortcut "$DESKTOP\DEETTY.lnk" "$INSTDIR\deetty.exe" "" "$INSTDIR\deetty.exe" 0
SectionEnd

Section /o "Desktop shortcut for NoctEd" SEC_DESKTOP_NOCTED
  SetShellVarContext current
  CreateShortcut "$DESKTOP\NoctEd.lnk" "$INSTDIR\nocted.exe" "" "$INSTDIR\nocted.exe" 0
SectionEnd

LangString DESC_SEC_CORE ${LANG_ENGLISH} "Native DEETTY terminal, NoctEd editor, Start Menu shortcuts, and reversible Open-With registration."
LangString DESC_SEC_DESKTOP_DEETTY ${LANG_ENGLISH} "Create an optional DEETTY shortcut on this user's desktop."
LangString DESC_SEC_DESKTOP_NOCTED ${LANG_ENGLISH} "Create an optional NoctEd shortcut on this user's desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CORE} $(DESC_SEC_CORE)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP_DEETTY} $(DESC_SEC_DESKTOP_DEETTY)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP_NOCTED} $(DESC_SEC_DESKTOP_NOCTED)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  SetShellVarContext current
  Delete "$DESKTOP\DEETTY.lnk"
  Delete "$DESKTOP\NoctEd.lnk"
  Delete "$SMPROGRAMS\DEETTY\DEETTY.lnk"
  Delete "$SMPROGRAMS\DEETTY\NoctEd.lnk"
  Delete "$SMPROGRAMS\DEETTY\Uninstall DEETTY.lnk"
  RMDir "$SMPROGRAMS\DEETTY"

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

  Delete "$INSTDIR\deetty.exe"
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
