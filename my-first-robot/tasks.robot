*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.PDF
Library             String
Library             RPA.Archive
Library             RPA.FileSystem
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault


*** Variables ***
${GLOBAL_RETRY_AMOUNT}=         10x
${GLOBAL_RETRY_INTERVAL}=       1s
${InputFileName}=               orders.csv
${InputFilePath}=               ./input${/}${InputFileName}
${ReceiptsPath}=                ${OUTPUT_DIR}${/}receipts
${ReceiptFileName}=             Receipt_order_number.pdf
${ScreenshotsPath}=             ${OUTPUT_DIR}${/}Screenshots
${ScreenshotFileName}=          Screenshot_order_number.png
${MainURL}=                     https://robotsparebinindustries.com/
${OrderURL}=                    ${MainURL}#/robot-order
${DownloadPath}                 ${MainURL}${InputFileName}
${ZipFileName}=                 PDFs.zip
${ZIPFilePath}=                 ${OUTPUT_DIR}${/}${ZipFileName}


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders}=    Get orders
    FOR    ${row}    IN    @{orders}
        Close the annoying modal

        Fill the form    ${row}
        Preview the robot
        Wait Until Keyword Succeeds
        ...    ${GLOBAL_RETRY_AMOUNT}
        ...    ${GLOBAL_RETRY_INTERVAL}
        ...    Submit the order

        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts
    Cleanup temporary folders


*** Keywords ***
Open the robot order website
    ${URLS}=    Get Secret    URLs
    Open Available Browser    ${URLS}[ordersURL]

Get orders
    ${result}=    Confirmation dialog
    Log    ${result.submit}
    IF    "${result.submit}" == "Yes"
        Download    ${DownloadPath}    overwrite=True    target_file=${InputFilePath}
    ELSE
        ${InputFilePath}=    Input form dialog
    END
    ${table}=    Read table from CSV    ${InputFilePath}
    RETURN    ${table}

Close the annoying modal
    Click Element If Visible    alias:Ok Button

Fill the form
    [Arguments]    ${data}
    Select From List By Value    alias:Head Selector    ${data}[Head]
    Select Radio Button    body    ${data}[Body]
    Input Text    alias:Legs Field    ${data}[Legs]
    Input Text    alias:Address Field    ${data}[Address]

Preview the robot
    Click Element If Visible    alias:Preview Button

Submit the order
    Click Element If Visible    alias:Order Button
    TRY
        Wait Until Element Is Visible    alias:Receipt    ${GLOBAL_RETRY_INTERVAL}
    EXCEPT
        ${error_message}=    Get Text    alias:Error Alert
        Fail    ${error_message}
    END

Store the receipt as a PDF file
    [Arguments]    ${OrderNumber}
    Wait Until Element Is Visible    alias:Receipt
    ${receipt_html}=    Get Element Attribute    alias:Receipt    outerHTML
    ${ReceiptFileName}=    Replace String    ${ReceiptFileName}    number    ${OrderNumber}
    ${PDFPath}=    Set Variable    ${ReceiptsPath}${/}${ReceiptFileName}
    Html To Pdf    ${receipt_html}    ${PDFPath}
    RETURN    ${PDFPath}

Take a screenshot of the robot
    [Arguments]    ${OrderNumber}
    Wait Until Element Is Visible    alias:RobotImagePreview
    ${ScreenshotFileName}=    Replace String    ${ScreenshotFileName}    number    ${OrderNumber}
    ${PNGPath}=    Set Variable    ${ScreenshotsPath}${/}${ScreenshotFileName}
    Screenshot    alias:RobotImagePreview    ${PNGPath}
    RETURN    ${PNGPath}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshotPath}    ${pdfPath}
    ${AppendItems}=    Create List    ${screenshotPath}
    Open Pdf    ${pdfPath}
    Add Files To Pdf    ${AppendItems}    ${pdfPath}    True

Go to order another robot
    Click Element If Visible    alias:OrderAnotherRobotButton

Create a ZIP file of the receipts
    Archive Folder With Zip    ${ReceiptsPath}    ${ZIPFilePath}
    Wait Until Created    ${ZIPFilePath}

Cleanup temporary folders
    Close All Pdfs
    Remove Directory    ${ReceiptsPath}    True
    Remove Directory    ${ScreenshotsPath}    True

Confirmation dialog
    Add icon    Warning
    Add heading    Download orders file?
    Add submit buttons    buttons=No,Yes    default=Yes
    ${result}=    Run dialog
    RETURN    ${result}

Input form dialog
    Add heading    Enter the orders file path
    Add text input    path
    ...    label=FilePath
    ...    placeholder=Enter file path here
    ...    rows=5
    ${InputFilePath}=    Run dialog
    RETURN    ${InputFilePath.path}
