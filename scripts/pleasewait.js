var submitDone = false;

function submitForm(myForm)
{
	if (!submitDone)
	{
		submitDone = true;
		document.getElementById('pleasewait').style.visibility = 'visible';
		myForm.submit();
	} 
	else
	{
		alert ("Already submitted, please wait!");
	}
	return true;
}
