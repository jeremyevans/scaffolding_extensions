function scaffold_form_focus() {
    num_forms = document.forms.length
    for(i=0;i<num_forms;i++) { 
        elements = document.forms[i].elements
        num_elements = elements.length
        for(j=0;j<num_elements;j++) {
            element = elements[j]
            tagName = element.tagName
            if(tagName == 'SELECT' || tagName == 'TEXTAREA' || (tagName == 'INPUT' && (element.type == 'text' || element.type == 'password'))) {
                if(tagName != 'SELECT') {
                    element.selectionStart = 0
                    element.selectionEnd = 0
                }
                element.focus()
                return
            }
        }
    }
}

scaffold_form_focus()
