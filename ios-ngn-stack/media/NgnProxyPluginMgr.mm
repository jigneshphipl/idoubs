#if TARGET_OS_IPHONE

#import "NgnProxyPluginMgr.h"
#import "iOSNgnConfig.h"

#import "ProxyConsumer.h"
#import "ProxyProducer.h"
#import "ProxyPluginMgr.h"

#import "NgnProxyVideoConsumer.h"
#import "NgnProxyVideoProducer.h"

#undef TAG
#define kTAG @"NgnProxyPluginMgr///: "
#define TAG kTAG

#undef kPlugins
#define kPlugins [NgnProxyPluginMgr getAllPlugins]

@interface NgnProxyPluginMgr (Private)
+(NSMutableDictionary*) getAllPlugins;
@end

class _NgnProxyPluginMgrCallback;

static _NgnProxyPluginMgrCallback* _sMyProxyPluginMgrCallback = tsk_null;
static ProxyPluginMgr* _sPluginMgr = tsk_null;

//
//	Plugin Manager callback function
//

class _NgnProxyPluginMgrCallback : public ProxyPluginMgrCallback
{
public:
	_NgnProxyPluginMgrCallback(){
	}
	
	virtual ~_NgnProxyPluginMgrCallback(){
	}
	
	
	int OnPluginCreated(uint64_t _id, enum twrap_proxy_plugin_type_e _type) {
		// This is a POSIX thread but thanks to multithreading
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		int ret = 0;
		NgnNSLog(TAG, @"OnPluginCreated(%lld,%d)", _id, _type);
		
		if(!_sPluginMgr){
			TSK_DEBUG_ERROR("Media engine not initialized");
			ret -1;
			goto done;
		}
		
		switch (_type) {
			case twrap_proxy_plugin_video_producer:
			{
				const ProxyVideoProducer* _producer = _sPluginMgr->findVideoProducer(_id);
				if(_producer){
					NgnProxyVideoProducer* ngnProducer = [[[NgnProxyVideoProducer alloc] initWithId: _id andProducer: _producer] autorelease];
					if(ngnProducer){
						@synchronized(kPlugins){
							[kPlugins setObject: ngnProducer forKey: [ngnProducer getIdAsNumber]];
						}
					}
				}
				break;
			}
				
			case twrap_proxy_plugin_video_consumer:
			{
				const ProxyVideoConsumer* _consumer = _sPluginMgr->findVideoConsumer(_id);
				if(_consumer){
					NgnProxyVideoConsumer* ngnConsumer = [[[NgnProxyVideoConsumer alloc] initWithId: _id andConsumer: _consumer] autorelease];
					if(ngnConsumer){
						@synchronized(kPlugins){
							[kPlugins setObject: ngnConsumer forKey: [ngnConsumer getIdAsNumber]];
						}
					}
				}
				break;
			}
				
			default:
			{
				NgnNSLog(TAG, @"Invalid Plugin type");
				ret -1;
				goto done;
			}
		}
done:
		[pool release];
		return ret; 
	}
	
	int OnPluginDestroyed(uint64_t _id, enum twrap_proxy_plugin_type_e _type) {
		// This is a POSIX thread but thanks to multithreading
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		int ret = 0;
		
		NgnNSLog(TAG, @"OnPluginDestroyed(%lld,%d)", _id, _type);
		
		switch (_type) {
			case twrap_proxy_plugin_video_producer:
			case twrap_proxy_plugin_video_consumer:
			{
				@synchronized(kPlugins){
					NSNumber* pluginId = [NSNumber numberWithLong: _id];
					NgnProxyPlugin* ngnPlugin = [kPlugins objectForKey: pluginId];
					if(ngnPlugin){
						[ngnPlugin makeInvalidate];
						[kPlugins removeObjectForKey: pluginId];
						ret = 0;
						goto done;
					}
					else{
						NgnNSLog(TAG, @"Failed to find plugin");
						ret = -1;
						goto done;
					}
				}
				break;
			}
				
			default:
			{
				NgnNSLog(TAG, @"Invalid Plugin type");
				ret = -1;
				goto done;
			}
		}
		
done:
		[pool release];
		return ret; 
	}
};



//
//	Plugin manager implementation
//

@implementation NgnProxyPluginMgr (Private)

+(NSMutableDictionary*) getAllPlugins{
	static NSMutableDictionary* sPlugins = nil;
	if(sPlugins == nil){
		sPlugins = [[NSMutableDictionary alloc] init];
	}
	return sPlugins;
}

@end

@implementation NgnProxyPluginMgr

+(void) initialize{
	ProxyVideoConsumer::setDefaultChroma(tmedia_rgb32);
	ProxyVideoConsumer::setDefaultAutoResizeDisplay(YES);
	ProxyVideoProducer::setDefaultChroma(tmedia_nv12);
	
	ProxyVideoProducer::registerPlugin();
	ProxyVideoConsumer::registerPlugin();
	
	if(!_sMyProxyPluginMgrCallback){
		_sMyProxyPluginMgrCallback  = new _NgnProxyPluginMgrCallback();
	}
	if(!_sPluginMgr && _sMyProxyPluginMgrCallback){
		_sPluginMgr = ProxyPluginMgr::createInstance(_sMyProxyPluginMgrCallback);
	}
}

+(NgnProxyPlugin*) getProxyPluginWithId: (uint64_t)_id{
	@synchronized(kPlugins){
		return [kPlugins objectForKey: [NSNumber numberWithLong: _id]];
	}
}

@end

#endif /* TARGET_OS_IPHONE */
