//Javascript name: My Date Time Picker
//Date created: 16-Nov-2003 23:19
//Scripter: TengYong Ng
//Website: http://www.rainforestnet.com
//Copyright (c) 2003 TengYong Ng
//FileName: DateTimePicker.js
//Version: 0.8
//Contact: contact@rainforestnet.com
// Note: Permission given to use this script in ANY kind of applications if
//       header lines are left unchanged.

//Global variables


// Modified by Zarina Mustapha January 11, 2005

var winCal;
var dtToday=new Date();
var Cal;
var docCal;
var MonthName=["January", "February", "March", "April", "May", "June","July","August", "September", "October", "November", "December"];
var WeekDayName=["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];	
var exDateTime;//Existing Date and Time

//Configurable parameters
var WindowTitle2 ="PMT Calendar View";//Date Time Picker title.
var WeekChar=3;//number of character for week day. if 2 then Mo,Tu,We. if 3 then Mon,Tue,Wed.
var DateSeparator="-";//Date Separator, you can change it to "/" if you want.

var ShowLongMonth=true;//Show long month name in Calendar header. example: "January".
var ShowMonthYear=true;//Show Month and Year in Calendar header.
var WeekHeadColor="name_of_days";//class of Days of the Week header.
var SundayColor="weekends";//class  of Sunday.
var SaturdayColor="weekends";//class of Saturday.
var WeekDayColor="weekdays";//class of  weekdays.
var TodayColor="todays_date";//class of today's date.
var SelDateColor="selected_day";//Class for selected date in textbox.
var MonthYearHeader="month_year";//class for month and year header.
var MonthMenu="month_selection";//class for month dropdown menu.
//end Configurable parameters
//end Global variable

// pCtrl is 'datebox'
//pFormat is 'ddmmyyyy'

function ViewNewCal(pCtrl,pFormat)
{
	//alert (pShowTime);
	Cal=new Calendar_v(dtToday);
	
	if (pCtrl!=null)
		Cal.Ctrl=pCtrl;
	if (pFormat!=null)
		Cal.Format=pFormat.toUpperCase();
	
	exDateTime=document.getElementById(pCtrl).value;
// exDateTime is date already in the textbox
	if (exDateTime!="")//Parse Date String
	{
		var Sp1;//Index of Date Separator 1
		var Sp2;//Index of Date Separator 2 
		var tSp1;//Index of Time Separator 1
		var tSp1;//Index of Time Separator 2
		var strMonth;
		var strDate;
		var strYear;
		var intMonth;
		var YearPattern;
		var strHour;
		var strMinute;
		var strSecond;
		//parse month
		Sp1=exDateTime.indexOf(DateSeparator,0)
		Sp2=exDateTime.indexOf(DateSeparator,(parseInt(Sp1)+1));
		//alert ('first separator: '+Sp1);alert ('second separator: '+Sp2);
		if ((Cal.Format.toUpperCase()=="DDMMYYYY") || (Cal.Format.toUpperCase()=="DDMMMYYYY"))
		{
			strMonth=exDateTime.substring(Sp1+1,Sp2);
			strDate=exDateTime.substring(0,Sp1);
		}
		else if ((Cal.Format.toUpperCase()=="YYYYMMDD"))
		{
			strMonth=exDateTime.substring(Sp1+1,Sp2);
			strDate=exDateTime.substring(Sp2+Sp1,Sp2+1);
	//alert ('month: '+strMonth);
	//alert ('day: '+strDate);
		}
		else if ((Cal.Format.toUpperCase()=="MMDDYYYY") || (Cal.Format.toUpperCase()=="MMMDDYYYY"))
		{
			strMonth=exDateTime.substring(0,Sp1);
			strDate=exDateTime.substring(Sp1+1,Sp2);
		}
		if (isNaN(strMonth))
			{intMonth=Cal.GetMonthIndex_v(strMonth);}
		else
			intMonth=parseInt(strMonth,10)-1;	
		if ((parseInt(intMonth,10)>=0) && (parseInt(intMonth,10)<12))
			{Cal.Month=intMonth;}
		//end parse month
		//parse Date
		if ((parseInt(strDate,10)<=Cal.GetMonDays_v()) && (parseInt(strDate,10)>=1))
			Cal.Date=strDate;
		//end parse Date
		//parse year, strYear is the year from textbox
		strYear=exDateTime.substring(0,Sp1);
		YearPattern=/^\d{4}$/;
		if (YearPattern.test(strYear))
			{Cal.Year=parseInt(strYear,10);}
		//end parse year
	}
	winCal=window.open("","DateTimePicker","toolbar=no,scrollbars=no,status=no,menubar=no,fullscreen=no,width=270,height=270,resizable=no,top=100,left=100");
	docCal=winCal.document;
	RenderCal_v();
}

function RenderCal_v()
{
	var vCalHeader;
	var vCalData;
	var i;
	var j;
	var SelectStr;
	var vDayCount=0;
	var vFirstDay;

	docCal.open();
	docCal.writeln('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">');
	docCal.writeln('<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">');
	docCal.writeln("<head><title>"+WindowTitle2+"</title>");
	docCal.writeln("<link rel='stylesheet' href='style/calendar.css' type='text/css' media='screen' />");
	docCal.writeln("<script type='text/javascript' language='javascript'>var winMain=window.opener;</script>");
	docCal.writeln("</head>");
	docCal.writeln("<body>");
	docCal.writeln("<form name='Calendar_v'>");

	vCalHeader="<table cellpadding='0' cellspacing='0' class='calendar'>\n";
	//Month Selector
	vCalHeader+="<tr>\n<td colspan='4' class='"+MonthYearHeader+"'>\n";
	vCalHeader+="<select class='"+MonthMenu+"' name=\"MonthSelector\" onchange=\"javascript:winMain.Cal.SwitchMth_v(this.selectedIndex);winMain.RenderCal_v();\">\n";
	for (i=0;i<12;i++)
	{
		if (i==Cal.Month)
			SelectStr="selected=\"selected\"";
		else
			SelectStr="";	
		vCalHeader+="<option class='month_name' "+SelectStr+" value=''>"+MonthName[i]+"</option>\n";
	}
	vCalHeader+="</select></td>";
	//Year selector
	vCalHeader+="\n<td colspan='3' class='"+MonthYearHeader+"' style='text-align: right;'><a href=\"javascript:winMain.Cal.DecYear_v();winMain.RenderCal_v()\">&#160;&lt;&#160;</a>&#160;"+Cal.Year+"&#160;<a href=\"javascript:winMain.Cal.IncYear_v();winMain.RenderCal_v()\">&#160;&gt;&#160;</a></td>\n";	
	vCalHeader+="</tr>";
	//Calendar header shows Month and Year
	//if (ShowMonthYear)
	//	vCalHeader+="<tr><td colspan='7'><b>"+Cal.GetMonthName_v(ShowLongMonth)+" "+Cal.Year+"</b></td></tr>\n";
	//Week day header
	vCalHeader+="<tr class='"+WeekHeadColor+"'>";
	for (i=0;i<7;i++)
	{
		vCalHeader+="<td align='center' class='name_of_days'>"+WeekDayName[i].substr(0,WeekChar)+"</td>"; //The days up on the top
	}
	vCalHeader+="</tr>";	
	docCal.write(vCalHeader);
	
	//Calendar detail
	CalDate=new Date(Cal.Year,Cal.Month);
	CalDate.setDate(1);
	vFirstDay=CalDate.getDay();
	vCalData="<tr>";
	for (i=0;i<vFirstDay;i++)
	{
		vCalData=vCalData+GenCell_v();
		vDayCount=vDayCount+1;
	}
	for (j=1;j<=Cal.GetMonDays_v();j++)
	{
		var strCell;
		vDayCount=vDayCount+1;
		if ((j==dtToday.getDate())&&(Cal.Month==dtToday.getMonth())&&(Cal.Year==dtToday.getFullYear()))
			strCell=GenCell_v(j,true,TodayColor);//Highlight today's date
		else
		{
			if (j==Cal.Date)
			{
				strCell=GenCell_v(j,true,SelDateColor);
			}
			else
			{	 
				if (vDayCount%7==0)
					strCell=GenCell_v(j,false,SaturdayColor);
				else if ((vDayCount+6)%7==0)
					strCell=GenCell_v(j,false,SundayColor);
				else
					strCell=GenCell_v(j,null,WeekDayColor);
			}		
		}						
		vCalData=vCalData+strCell;

		if((vDayCount%7==0)&&(j<Cal.GetMonDays_v()))
		{
			vCalData=vCalData+"</tr>\n<tr>";
		}
	}
	docCal.writeln(vCalData);	

	docCal.writeln("\n</tr>\n<tr><td colspan='7' class='closewin'><a href='javascript:window.close();'>close</a></td></tr></table>");
	docCal.writeln("</form></body></html>");
	docCal.close();
}

function GenCell_v(pValue,pHighLight,pColor)//Generate table cell with value
{
	var PValue;
	var PCellStr;
	var vColor;
	var vHLstr1;//HighLight string
	var vHlstr2;
	
	if (pValue==null)
		PValue="";
	else
		PValue=pValue;
	
	if (pColor!=null)
		vColor="class='"+pColor+"'";
	else
		vColor="";	
	if ((pHighLight!=null)&&(pHighLight))
		{vHLstr1="color='red'><b>";vHLstr2="</b>";}
	else
		{vHLstr1=">";vHLstr2="";}	
	
		if  (PValue=="") {PCellStr="<td>&#160;</td>";}
		else 
		{PCellStr="<td "+vColor+">"+PValue+"</td>";
		}
	return PCellStr;
}

function Calendar_v(pDate,pCtrl)
{
	//Properties
	this.Date=pDate.getDate();//selected date
	this.Month=pDate.getMonth();//selected month number
	this.Year=pDate.getFullYear();//selected year in 4 digits
	
	if (pDate.getMinutes()<10)
		this.Minutes="0"+pDate.getMinutes();
	else
		this.Minutes=pDate.getMinutes();
	
	if (pDate.getSeconds()<10)
		this.Seconds="0"+pDate.getSeconds();
	else		
		this.Seconds=pDate.getSeconds();
		
	this.MyWindow=winCal;
	this.Ctrl=pCtrl;
	this.Format="ddMMyyyy";
	this.Separator=DateSeparator;
}

function GetMonthIndex_v(shortMonthName)
{
	for (i=0;i<12;i++)
	{
		if (MonthName[i].substring(0,3).toUpperCase()==shortMonthName.toUpperCase())
		{	return i;}
	}
}
Calendar_v.prototype.GetMonthIndex_v=GetMonthIndex_v;

function IncYear_v()
{	Cal.Year++;}
Calendar_v.prototype.IncYear_v=IncYear_v;

function DecYear_v()
{	Cal.Year--;}
Calendar_v.prototype.DecYear_v=DecYear_v;
	
function SwitchMth_v(intMth)
{	Cal.Month=intMth;}
Calendar_v.prototype.SwitchMth_v=SwitchMth_v;

function GetMonthName_v(IsLong)
{
	var Month=MonthName[this.Month];
	if (IsLong)
		return Month;
	else
		return Month.substr(0,3);
}
Calendar_v.prototype.GetMonthName_v=GetMonthName_v;

function GetMonDays_v()//Get number of days in a month
{
	var DaysInMonth=[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
	if (this.IsLeapYear_v())
	{
		DaysInMonth[1]=29;
	}	
	return DaysInMonth[this.Month];	
}
Calendar_v.prototype.GetMonDays_v=GetMonDays_v;

function IsLeapYear_v()
{
	if ((this.Year%4)==0)
	{
		if ((this.Year%100==0) && (this.Year%400)!=0)
		{
			return false;
		}
		else
		{
			return true;
		}
	}
	else
	{
		return false;
	}
}
Calendar_v.prototype.IsLeapYear_v=IsLeapYear_v;

function FormatDate_v(pDate)
{
	if (this.Format.toUpperCase()=="YYYYMMDD")
		{
			if (((this.Month+1) < 10) && (pDate < 10)) return (this.Year+DateSeparator+'0'+(this.Month+1)+DateSeparator+'0'+pDate);
			else if ((this.Month+1) < 10) return (this.Year+DateSeparator+'0'+(this.Month+1)+DateSeparator+pDate);
			else if (pDate < 10) return (this.Year+DateSeparator+(this.Month+1)+DateSeparator+'0'+pDate);
			else return (this.Year+DateSeparator+(this.Month+1)+DateSeparator+pDate);
		}
	else if (this.Format.toUpperCase()=="DDMMMYYYY")
		return (pDate+DateSeparator+this.GetMonthName_v(false)+DateSeparator+this.Year);
	else if (this.Format.toUpperCase()=="MMDDYYYY")
		return ((this.Month+1)+DateSeparator+pDate+DateSeparator+this.Year);
	else if (this.Format.toUpperCase()=="MMMDDYYYY")
		return (this.GetMonthName_v(false)+DateSeparator+pDate+DateSeparator+this.Year);			
}
Calendar_v.prototype.FormatDate_v=FormatDate_v;	