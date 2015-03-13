This is a tiny, yet complete, XML-RPC client object in ActionScript3.

I always liked XML-RPC because it's a pretty commonsense way to pass information back and forth between client and server. Also it's dirt-simple to implement in PHP, and anything that minimizes the amount of server work I need to do is fine in my book.

Only problem is that the XML-RPC mechanisms I found for AS were either Flex-only, weren't for AS3, were abandoned very early on, or were overly complicated. Given that E4X raises (or lowers) XML to the status of a primitive data-type in AS3, and AS has had http communication since the beginning, it made no sense that RPC mechanisms should be complicated. So I wrote a small one that fits in a single 200-line AS3 file, consisting of one object which contains one public function to do the call and set the receive the response

As it stands, it seems to work. Enjoy!
