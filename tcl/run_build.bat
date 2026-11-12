@echo off
setlocal EnableDelayedExpansion

:: =====================================================================================
:: Color codes for the console
:: =====================================================================================
for /f %%a in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%a"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RESET=%ESC%[0m"

:: =====================================================================================
:: Check for help call
:: =====================================================================================
if "%~1" == "" goto display_help
if "%~1" == "--help" goto display_help

:: =====================================================================================
:: The first argument is the path
:: =====================================================================================
set "BUILD_DIR=%~1"
set "PROJECT_NAME=SLA_IIR"
set "TOP_ENTITY=SLA_IIR"

:: =====================================================================================
:: Checking the specified parameters
:: =====================================================================================
set "ALLOWED_FLAGS= -F_CLK -F_S -FILTER_TYPE -FILTER_APPROX -F_PASS -F_STOP -F_PASS1 -F_PASS2 -F_STOP1 -F_STOP2 -A_PASS -A_STOP -A_PASS1 -A_PASS2 -A_STOP1 -A_STOP2 -IN_WL -IN_FL -H_WL -OUT_WL -OUT_FL -SEC_IN_WL -SEC_OUT_WL "
set "IS_FIRST=1"
set "EXPECT_VALUE=0"
set "LAST_FLAG="

for %%a in (%*) do (
	if "!IS_FIRST!"=="1" (
		set "IS_FIRST=0"
	) else (
		set "ITEM=%%a"
		set "FIRST_CHAR=!ITEM:~0,1!"
		
		if "!EXPECT_VALUE!"=="0" (
			:: Check for flag receipt
			if not "!FIRST_CHAR!"=="-" (
				echo %RED%[ERROR] Violation of command format. Expected a flag starting with "-", received: "!ITEM!"%RESET%
				pause
				exit /b 1
			)
			:: Whitelist check
			echo %ALLOWED_FLAGS% | findstr /I /C:" !ITEM! " > nul
			if errorlevel 1 (
				echo %RED%[ERROR] Unknown parameter: !ITEM!. Allowed parameters: %ALLOWED_FLAGS%%RESET%
				pause
				exit /b 1
			)
			
			set "LAST_FLAG="!ITEM!"
			set "EXPECT_VALUE=1"
		) else (
			:: Checking to get the value after the flag
			if "!FIRST_CHAR!"=="-" (
				echo %RED%[ERROR] No value specified for the "!LAST_FLAG!" flag.%RESET%
				pause
				exit /b 1
			)
			set "EXPECT_VALUE=0"
		)
	)
)

:: Check for value at the end
if "!EXPECT_VALUE!"=="1" (
	echo %RED%[ERROR] "!LAST_FLAG!" flag is specified without value.%RESET%
	pause
	exit /b 1
)

:: =====================================================================================
:: Preparing arguments for MATLAB
:: =====================================================================================
set "MATLAB_ARGS="
for /f "tokens=1,* delims= " %%a in ("%*") do set "RAW_FLAGS=%%b"

if defined RAW_FLAGS (
	setlocal enabledelayedexpansion
	for %%i in (!RAW_FLAGS!) do (
		if not defined MATLAB_ARGS (
			set "MATLAB_ARGS='%%~i'"
		) else (
			set "MATLAB_ARGS=!MATLAB_ARGS!, '%%~i'"
		)
	)
)

:: =====================================================================================
:: Start of the MATLAB script to generate files
:: =====================================================================================
echo %YELLOW%[INFO] Running the MATLAB script to generate IIR coefficients, stimulus and header for RTL...%RESET%
matlab -batch "addpath('../matlab'); SLA_IIR_calc_auto('%BUILD_DIR%', {%MATLAB_ARGS%});"

if %ERRORLEVEL% equ 0 (
	echo %GREEN%[SUCCESS] Files generation completed successfully.%RESET%
) else (
	echo %RED%[ERROR] Files generation completed with errors.%RESET%
	pause
	exit /b 1
)

:: =====================================================================================
:: Start build tcl-script with input arguments
:: =====================================================================================
echo %YELLOW%[INFO] Starting the project build...%RESET%
echo %YELLOW%[INFO] Target directory: %BUILD_DIR%%RESET%

quartus_sh.exe -t build.tcl %*

if %ERRORLEVEL% equ 0 (
	echo %GREEN%[SUCCESS] The project has been successfully built.%RESET%
) else (
	echo %RED%[ERROR] An error occurred during the build.%RESET%
	pause
	exit /b 1
)

:: =====================================================================================
:: Start STA tcl-script with input arguments
:: =====================================================================================
quartus_sta -t timing.tcl "%BUILD_DIR%"
if %ERRORLEVEL% equ 0 (
	echo %GREEN%[SUCCESS] STA completed successfully.%RESET%
) else (
	echo %RED%[ERROR] STA completed with errors.%RESET%
	pause
	exit /b 1
)

:: =====================================================================================
:: Start of simulation
:: =====================================================================================
set "MODELSIM="
set "SIM_BUILD_DIR=%BUILD_DIR:\=/%"
set "SIM_TCL_PATH=%~dp0sim.tcl"
set "SIM_TCL_PATH=%SIM_TCL_PATH:\=/%"

vsim -c -do "set argv %SIM_BUILD_DIR%; set argc [llength $argv]; source {%SIM_TCL_PATH%}; quit -f"
if %ERRORLEVEL% equ 0 (
	echo %GREEN%[SUCCESS] Simulation completed successfully.%RESET%
) else (
	echo %RED%[ERROR] Simulation completed with errors.%RESET%
	pause
	exit /b 1
)

:: =====================================================================================
:: Start the MATLAB script to compare module outputs with references
:: =====================================================================================
echo %YELLOW%[INFO] Starting the MATLAB Script...%RESET%
matlab -batch "addpath('../matlab'); IIR_analyze_auto('%BUILD_DIR%');"

if %ERRORLEVEL% equ 0 (
	echo %GREEN%[SUCCESS] Comparison completed successfully.%RESET%
) else (
	echo %RED%[ERROR] Comparison completed with errors.%RESET%
	pause
	exit /b 1
)	

pause
exit /b 0

:: =====================================================================================
:: Help output function
:: =====================================================================================
:display_help
echo %YELLOW%=======================================================================================
echo                                Project Build Script Help
echo =======================================================================================
echo.
echo Using the command:
echo 	run_build.bat ^<build_path^> [parameter_flags]
echo.
echo Available parameter flags:
echo 	-F_CLK ^<value^>				Clock
echo 	-F_S ^<value^>				Sampling frequency
echo 	-FILTER_TYPE ^<string^>			Filter Type (lowpass, highpass, bandpass, bandstop)
echo 	-FILTER_APPROX ^<string^> 		Design Method (butter, ellip, cheby1, cheby2)
echo 	-F_PASS ^<value^>				Passband edge
echo 	-F_STOP ^<value^>				Stopband edge
echo 	-F_PASS1 ^<value^>			First Passband edge
echo 	-F_PASS2 ^<value^>			Second Passband edge
echo 	-F_STOP1 ^<value^>			First Stopband edge
echo 	-F_STOP2 ^<value^>			Stopband edge
echo 	-A_PASS ^<value^>				Passband ripple in dB
echo 	-A_STOP ^<value^>				Stopband ripple in dB
echo 	-A_PASS1 ^<value^>			First Passband ripple in dB
echo 	-A_PASS2 ^<value^>			Second Passband ripple in dB
echo 	-A_STOP1 ^<value^>			First Stopband ripple in dB
echo 	-A_STOP2 ^<value^>			Second Stopband ripple in dB
echo 	-IN_WL ^<value^>				Input signal word length
echo 	-IN_FL ^<value^>				Input signal fraction length
echo 	-H_WL ^<value^>				Coefficients Word length
echo 	-OUT_WL ^<value^>				Output signal word length
echo 	-OUT_FL ^<value^>				Output signal fraction length
echo 	-SEC_IN_WL ^<value^>			Section input word length
echo 	-SEC_OUT_WL ^<value^>			Section output word length
echo.
echo Note:
echo 	All unspecified parameters will take the default values specified in the HDL.
echo.
echo Call examples:
echo 	run_build.bat ./build_out
echo	run_build.bat ./build_out -F_CLK 100000000 -F_S 100000000 -F_PASS 10000000 
echo -F_STOP 15000000 -FILTER_TYPE lowpass -FILTER_APPROX butter -A_PASS 0.1 -A_STOP 60 
echo -IN_WL 16 -IN_FL 15 -H_WL 16 -OUT_WL 20 -SEC_IN_WL 20 -SEC_OUT_WL 20 -STATE_WL 20 
echo -STATE_FL 16
echo 	run_build.bat ./build_out -F_CLK 100000000 -F_S 100000000 -F_STOP1 7000000 
echo -F_PASS1 10000000 -F_PASS2 15000000 -F_STOP2 18000000 -FILTER_TYPE bandpass 
echo -FILTER_APPROX cheby1 -A_STOP1 60 -A_PASS 0.1 -A_STOP2 60 -IN_WL 16 -IN_FL 15 
echo -H_WL 16 -OUT_WL 16 -OUT_FL 15 -SEC_IN_WL 16 -SEC_OUT_WL 16
echo =======================================================================================%RESET%
pause
exit /b 0