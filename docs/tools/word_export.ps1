param([string]$Docx, [string]$Pdf)
# Abre el .docx generado en una instancia propia de Word (no toca el Word del usuario),
# compacta y actualiza el índice, guarda y exporta a PDF. Imprime el número de páginas.
# Uso: powershell -File docs/tools/word_export.ps1 <archivo.docx> <archivo.pdf>
$job = Start-Job -ScriptBlock {
  param($docx, $pdf)
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $word.DisplayAlerts = 0
  try {
    $doc = $word.Documents.Open($docx)
    # Estilos integrados del índice (wdStyleTOC1 = -20, wdStyleTOC2 = -21): sin espacio extra,
    # para que el índice quepa en una página y no deje una página en blanco detrás.
    foreach ($id in @(-20, -21)) {
      $st = $doc.Styles.Item($id)
      $st.ParagraphFormat.SpaceBefore = 0
      $st.ParagraphFormat.SpaceAfter = 0
      $st.ParagraphFormat.LineSpacingRule = 0  # sencillo
      $st.Font.Size = 9.5
    }
    $doc.TablesOfContents(1).Update()
    $doc.Save()
    $doc.ExportAsFixedFormat($pdf, 17)
    "pages=" + $doc.ComputeStatistics(2)
    $doc.Close()
  } finally { $word.Quit() }
} -ArgumentList $Docx, $Pdf
if (Wait-Job $job -Timeout 150) { Receive-Job $job } else { "timeout"; Stop-Job $job }
Remove-Job $job -Force
