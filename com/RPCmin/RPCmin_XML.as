package com.RPCmin
{
	import flash.utils.Dictionary

	import flash.events.Event
	import flash.events.SecurityErrorEvent
	import flash.events.IOErrorEvent

	import flash.net.URLLoader
	import flash.net.URLRequest
	import flash.net.URLRequestMethod

	public class RPCmin_XML
	{
		protected static var reqs:Dictionary = new Dictionary()
		private var url:String

		public function RPCmin_XML(_url:String) 
		{
			url = _url
		}

		public static function handler(evt:Event)
		{
			var req = RPCmin_XML.reqs[evt.target]
			if (req)
			{
				if (req[0] && (evt.type == Event.COMPLETE))
				{	// we got something serialized, deserialize and call
					var strErr:String
					// make sure there's XML. Also, if your PHP warns, it'll post the error before your XML, so scrub that off
					var startXML:Number = evt.target.data.indexOf('<?xml')

					if (startXML != -1)
					{	// okay, there's some XML here
//						trace('received = '+evt.target.data)
						var xmlresult:XML = new XML(evt.target.data.substring(startXML))
						var resultvaluexml:XMLList = xmlresult.params.param.value
						if (resultvaluexml.toString() != '')	// okay, we got a result and a place to send it, so send it
							req[0](decodeObject(resultvaluexml))
						else if (req[1])	// there's a fault handler
						{	// not a loader fault, but an XML-RPC fault (most likely calling an undefined function)
							if (xmlresult.fault.value)
							{
								var faultobj = decodeObject(xmlresult.fault.value)
								strErr = faultobj.faultCode + ' ' + faultobj.faultString
							}
							else
								strErr = 'XML Error: ' + evt.target.data	// valid XML, but no fault code
						}
					}
					else
						strErr = 'XML Error: ' + evt.target.data	// most likely we didn't get back XML, so just send back what we got
				}
				else	// loader fault (server timeout, etc), so just send along the fault code
					strErr = evt.type

				if (strErr && req[1])	// there's a fault handler, so call it
					req[1](strErr)

				delete RPCmin_XML.reqs[evt.target]	// done, so clear the loader from the queue
			}
		}

		public function call(method:String, params:Array, fnSuccess:Function, fnFault:Function)
		{	// build the request
			var urlRequest:URLRequest = new URLRequest(url)
			urlRequest.contentType = 'text/xml'
			urlRequest.method = URLRequestMethod.POST
			
			// serialize the data into nice RPC compatible XML
			var xmlrpc:XML = <methodCall><methodName>{method}</methodName></methodCall>
			if (params.length > 0)
			{
				var tparams:XML = <params></params>
				for each (var param:* in params)
					tparams.appendChild(<param><value>{encodeObject(param)}</value></param>)

				xmlrpc.insertChildAfter(xmlrpc.methodName,tparams)
			}

			urlRequest.data = xmlrpc
//			trace ('sent = ' + xmlrpc)

			var loader:URLLoader = new URLLoader()	// now set up a place to go when this is done happening
			loader.addEventListener(Event.COMPLETE, RPCmin_XML.handler )
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, RPCmin_XML.handler )
			loader.addEventListener(IOErrorEvent.IO_ERROR, RPCmin_XML.handler )
			loader.load(urlRequest)

			reqs[loader] = [fnSuccess, fnFault]	// and queue the loader so we can call functions later
		}

		internal static const TYPE_INT:String = 'int'
		internal static const TYPE_I4:String = 'i4'
		internal static const TYPE_DOUBLE:String = 'double'
		internal static const TYPE_STRING:String = 'string'
		internal static const TYPE_BOOLEAN:String = 'boolean'
		internal static const TYPE_ARRAY:String = 'array'
		internal static const TYPE_STRUCT:String = 'struct'
		internal static const TYPE_DATE:String = 'dateTime.iso8601'

		protected static function isoPad (val:int):String
		{	// pad something to two digits, as iso8601 dates want that
			return (val < 10) ? '0'+String(val) : String(val)
		}

		protected static function encodeObject(obToEncode:*):XMLList
		{	// make an object into XML <type>object</type>
			var retVal:XMLList
			if (obToEncode is Number && Math.floor(obToEncode) == obToEncode)
				retVal = new XMLList('<'+TYPE_INT+'>' + obToEncode + '</'+TYPE_INT+'>')
			else if (obToEncode is Boolean)
				retVal = new XMLList('<'+TYPE_BOOLEAN+'>' + (obToEncode ? '1' : '0') + '</'+TYPE_BOOLEAN+'>')
			else if (obToEncode is Number)
				retVal =  new XMLList('<'+TYPE_DOUBLE+'>' + obToEncode + '</'+TYPE_DOUBLE+'>')
			else if (obToEncode is Date)	// reformat the date to iso8601
				retVal = new XMLList('<'+TYPE_DATE+'>' + obToEncode.fullYear + isoPad(obToEncode.month + 1) + isoPad(obToEncode.date) + 'T' + isoPad(obToEncode.hoursUTC) + ':' + isoPad(obToEncode.minutesUTC) + ':' + isoPad(obToEncode.secondsUTC) + 'Z' + '</'+TYPE_DATE+'>')
			else if (obToEncode is Array)
			{
				var tarraydataxml:XML = <data></data>
				for (var i:int; i<obToEncode.length; i++)
					tarraydataxml.appendChild(<value>{encodeObject(obToEncode[i])}</value>)

				var tarrayxml:XML = <array></array>
				tarrayxml.appendChild(tarraydataxml)
				retVal = new XMLList(tarrayxml)
			}
			else
			{	// it's something else, see if this object has members
				var tstructxml:XML = <struct></struct>
				for (var j:* in obToEncode)
					tstructxml.appendChild(<member><name>{j}</name><value>{encodeObject(obToEncode[j])}</value></member>)

				if (tstructxml.hasComplexContent())	// did we actually add any members?
					retVal = new XMLList(tstructxml)	// yes, so make a complex structure
				else	// if all else fails, it's a string
					retVal = new XMLList('<'+TYPE_STRING+'>' + (obToEncode as String) + '</'+TYPE_STRING+'>')
			}
			
			return retVal
		}
	
		protected static function decodeObject(obToDecode:*):*
		{	// get some <type>object</type> XML and magic it back to a typed object
			var retVal:*
			var type = obToDecode.children().name()

			if ((type == TYPE_INT) || (type == TYPE_I4))
				retVal = int(obToDecode.children())
			else if (type == TYPE_BOOLEAN)
			{
				var b = obToDecode.children()
				if (isNaN(b))
					retVal = (b.toLowerCase() == 'true') ? true : false
				else
					retVal = Boolean(Number(b))
			}
			else if (type == TYPE_DATE)
			{	// convert iso8601 back to AS3 date format
				var d:Array = obToDecode.children().match(/^(-?\d\d\d\d)-?(\d\d)-?(\d\d)T(\d\d):(\d\d):(\d\d)/)
				retVal = new Date(d[1],d[2]-1,d[3],d[4],d[5],d[6])
			}
			else if (type == TYPE_ARRAY)
			{
				retVal = new Array()
				for each (var value:* in obToDecode.array.data.value)
					retVal.push(decodeObject(value))
			}
			else if (type == TYPE_STRUCT)
			{
				retVal = new Object()
				for each (var member:* in obToDecode.struct.member)
					retVal[member.name] = decodeObject(member.value)
			}
			else
				retVal = String(obToDecode.children())

			return retVal
		}
	}
}