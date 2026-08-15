Unicode true
ManifestDPIAware true
RequestExecutionLevel user

!ifndef NOCTTY_PAYLOAD
  !error "NOCTTY_PAYLOAD must name the portable payload directory"
!endif
!ifndef NOCTTY_OUTPUT
  !error "NOCTTY_OUTPUT must name the installer output"
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

!define PRODUCT_NAME "NOCTTY"
!define PRODUCT_PUBLISHER "NOCTTY contributors"
!define PRODUCT_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\NOCTTY"
!define NOCTED_APP_KEY "Software\Classes\Applications\nocted.exe"
!define NOCTED_PROGID_KEY "Software\Classes\NoctEd.Text"

Name "${PRODUCT_NAME}"
OutFile "${NOCTTY_OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\NOCTTY"
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
VIAddVersionKey /LANG=1033 "FileDescription" "NOCTTY per-user installer"
VIAddVersionKey /LANG=1033 "LegalCopyright" "NOCTTY contributors"

!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${NOCTTY_PAYLOAD}/LICENSE"
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

Section "NOCTTY and NoctEd (required)" SEC_CORE
  SectionIn RO
  SetShellVarContext current
  SetOverwrite on
  SetOutPath "$INSTDIR"
  File /oname=noctty.exe "${NOCTTY_PAYLOAD}/noctty.exe"
  File /oname=nocted.exe "${NOCTTY_PAYLOAD}/nocted.exe"
  File /oname=LICENSE "${NOCTTY_PAYLOAD}/LICENSE"
  File /oname=THIRD_PARTY_NOTICES.md "${NOCTTY_PAYLOAD}/THIRD_PARTY_NOTICES.md"
  File /oname=WINDOWS.md "${NOCTTY_PAYLOAD}/WINDOWS.md"
  File /oname=WINDOWS-SMOKE.ps1 "${NOCTTY_PAYLOAD}/WINDOWS-SMOKE.ps1"
  File /oname=BUILD-INFO.txt "${NOCTTY_PAYLOAD}/BUILD-INFO.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\NOCTTY"
  CreateShortcut "$SMPROGRAMS\NOCTTY\NOCTTY.lnk" "$INSTDIR\noctty.exe" "" "$INSTDIR\noctty.exe" 0
  CreateShortcut "$SMPROGRAMS\NOCTTY\NoctEd.lnk" "$INSTDIR\nocted.exe" "" "$INSTDIR\nocted.exe" 0
  CreateShortcut "$SMPROGRAMS\NOCTTY\Uninstall NOCTTY.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayVersion" "${PRODUCT_VERSION}.${PACKAGE_REVISION}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_KEY}" "DisplayIcon" "$INSTDIR\noctty.exe"
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

Section /o "Desktop shortcut for NOCTTY" SEC_DESKTOP_NOCTTY
  SetShellVarContext current
  CreateShortcut "$DESKTOP\NOCTTY.lnk" "$INSTDIR\noctty.exe" "" "$INSTDIR\noctty.exe" 0
SectionEnd

Section /o "Desktop shortcut for NoctEd" SEC_DESKTOP_NOCTED
  SetShellVarContext current
  CreateShortcut "$DESKTOP\NoctEd.lnk" "$INSTDIR\nocted.exe" "" "$INSTDIR\nocted.exe" 0
SectionEnd

LangString DESC_SEC_CORE ${LANG_ENGLISH} "Native NOCTTY terminal, NoctEd editor, Start Menu shortcuts, and reversible Open-With registration."
LangString DESC_SEC_DESKTOP_NOCTTY ${LANG_ENGLISH} "Create an optional NOCTTY shortcut on this user's desktop."
LangString DESC_SEC_DESKTOP_NOCTED ${LANG_ENGLISH} "Create an optional NoctEd shortcut on this user's desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CORE} $(DESC_SEC_CORE)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP_NOCTTY} $(DESC_SEC_DESKTOP_NOCTTY)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP_NOCTED} $(DESC_SEC_DESKTOP_NOCTED)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  SetShellVarContext current
  Delete "$DESKTOP\NOCTTY.lnk"
  Delete "$DESKTOP\NoctEd.lnk"
  Delete "$SMPROGRAMS\NOCTTY\NOCTTY.lnk"
  Delete "$SMPROGRAMS\NOCTTY\NoctEd.lnk"
  Delete "$SMPROGRAMS\NOCTTY\Uninstall NOCTTY.lnk"
  RMDir "$SMPROGRAMS\NOCTTY"

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

  Delete "$INSTDIR\noctty.exe"
  Delete "$INSTDIR\nocted.exe"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.md"
  Delete "$INSTDIR\WINDOWS.md"
  Delete "$INSTDIR\WINDOWS-SMOKE.ps1"
  Delete "$INSTDIR\BUILD-INFO.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd
