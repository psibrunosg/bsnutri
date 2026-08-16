function escapeHtml(value:string){return value.replace(/[&<>"']/g,char=>({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[char]??char))}

export function printClinicalDocument(title:string,subtitle:string,body:string){
  const popup=window.open('', '_blank', 'noopener,noreferrer')
  if(!popup)return false
  popup.document.write(`<!doctype html><title>${escapeHtml(title)}</title><style>body{font-family:system-ui;margin:42px;color:#25372f}h1{color:#3e6b5c}pre{white-space:pre-wrap;font:inherit;line-height:1.55}</style><h1>${escapeHtml(title)}</h1><p>${escapeHtml(subtitle)}</p><pre>${escapeHtml(body)}</pre>`)
  popup.document.close()
  popup.focus()
  popup.print()
  return true
}
