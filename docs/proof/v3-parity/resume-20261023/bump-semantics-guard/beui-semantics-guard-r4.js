(function dartProgram(){function copyProperties(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
b[r]=a[r]}}function mixinPropertiesHard(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
if(!b.hasOwnProperty(r)){b[r]=a[r]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var t=function(){}
t.prototype={p:{}}
var s=new t()
if(!(Object.getPrototypeOf(s)&&Object.getPrototypeOf(s).p===t.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var r=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(r))return true}}catch(q){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var t=Object.create(b.prototype)
copyProperties(a.prototype,t)
a.prototype=t}}function inheritMany(a,b){for(var t=0;t<b.length;t++){inherit(b[t],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){var s=d()
if(a[b]!==t){A.dQ(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.I(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.bu(b)
return new t(c,this)}:function(){if(t===null)t=A.bu(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.bu(a).prototype
return t}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var t=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var s=staticTearOffGetter(t)
a[b]=s}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var t=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var s=instanceTearOffGetter(c,t)
a[b]=s}function setOrUpdateInterceptorsByTag(a){var t=v.interceptorsByTag
if(!t){v.interceptorsByTag=a
return}copyProperties(a,t)}function setOrUpdateLeafTags(a){var t=v.leafTags
if(!t){v.leafTags=a
return}copyProperties(a,t)}function updateTypes(a){var t=v.types
var s=t.length
t.push.apply(t,a)
return s}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var t=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},s=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:t(0,0,null,["$0"],0),_instance_1u:t(0,1,null,["$1"],0),_instance_2u:t(0,2,null,["$2"],0),_instance_0i:t(1,0,null,["$0"],0),_instance_1i:t(1,1,null,["$1"],0),_instance_2i:t(1,2,null,["$2"],0),_static_0:s(0,null,["$0"],0),_static_1:s(1,null,["$1"],0),_static_2:s(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
bz(a,b,c,d){return{i:a,p:b,e:c,x:d}},
bx(a){var t,s,r,q,p,o="_$dart_js",n=a[v.dispatchPropertyName]
if(n==null)if($.by==null){A.dG()
n=a[v.dispatchPropertyName]}if(n!=null){t=n.p
if(!1===t)return n.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return n.i
if(n.e===s)throw A.j(A.bP("Return interceptor for "+A.o(t(a,n))))}r=a.constructor
if(r==null)q=null
else{p=$.b1
if(p==null)p=$.b1=A.bd(o)
q=r[p]}if(q!=null)return q
q=A.dM(a)
if(q!=null)return q
if(typeof a=="function")return B.o
t=Object.getPrototypeOf(a)
if(t==null)return B.e
if(t===Object.prototype)return B.e
if(typeof r=="function"){p=$.b1
if(p==null)p=$.b1=A.bd(o)
Object.defineProperty(r,p,{value:B.b,enumerable:false,writable:true,configurable:true})
return B.b}return B.b},
ao(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.av.prototype
return J.aw.prototype}if(typeof a=="string")return J.O.prototype
if(a==null)return J.a2.prototype
if(typeof a=="boolean")return J.au.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.y.prototype
if(typeof a=="symbol")return J.a5.prototype
if(typeof a=="bigint")return J.a3.prototype
return a}if(a instanceof A.h)return a
return J.bx(a)},
ce(a){if(typeof a=="string")return J.O.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.y.prototype
if(typeof a=="symbol")return J.a5.prototype
if(typeof a=="bigint")return J.a3.prototype
return a}if(a instanceof A.h)return a
return J.bx(a)},
bc(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.y.prototype
if(typeof a=="symbol")return J.a5.prototype
if(typeof a=="bigint")return J.a3.prototype
return a}if(a instanceof A.h)return a
return J.bx(a)},
cp(a,b){if(typeof b==="number")if(Array.isArray(a)||A.dK(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.bc(a).k(a,b)},
cq(a,b){return J.bc(a).t(a,b)},
cr(a,b){return J.bc(a).B(a,b)},
bB(a){return J.bc(a).gq(a)},
bl(a){return J.ce(a).gj(a)},
cs(a){return J.ao(a).gi(a)},
X(a){return J.ao(a).h(a)},
ar:function ar(){},
au:function au(){},
a2:function a2(){},
a4:function a4(){},
C:function C(){},
aH:function aH(){},
ad:function ad(){},
y:function y(){},
a3:function a3(){},
a5:function a5(){},
l:function l(a){this.$ti=a},
at:function at(){},
aU:function aU(a){this.$ti=a},
Z:function Z(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
ax:function ax(){},
av:function av(){},
aw:function aw(){},
O:function O(){}},A={bn:function bn(){},
cg(a){var t,s
for(t=$.A.length,s=0;s<t;++s)if(a===$.A[s])return!0
return!1},
R:function R(){},
a0:function a0(a,b){this.a=a
this.$ti=b},
ae:function ae(){},
a1:function a1(a,b){this.a=a
this.$ti=b},
aV:function aV(a){this.a=a},
a6:function a6(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
n:function n(){},
am:function am(){},
cm(a){var t=A.cl(a)
if(t!=null)return t
return"minified:"+a},
dK(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
o(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.X(a)
return t},
aI(a){var t,s,r,q
if(a instanceof A.h)return A.r(A.V(a),null)
t=J.ao(a)
if(t===B.m||t===B.p||u.o.b(a)){s=B.c(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.r(A.V(a),null)},
cG(a){var t,s,r
if(typeof a=="number"||A.bt(a))return J.X(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.B)return a.h(0)
t=$.co()
for(s=0;s<1;++s){r=t[s].I(a)
if(r!=null)return r}return"Instance of '"+A.aI(a)+"'"},
t(a,b){if(a==null)J.bl(a)
throw A.j(A.bv(a,b))},
bv(a,b){var t,s="index"
if(!A.c6(b))return new A.Y(!0,b,s,null)
t=J.bl(a)
if(b<0||b>=t)return A.bJ(b,t,a,s)
return new A.aJ(null,null,!0,b,s,"Value not in range")},
j(a){return A.m(a,new Error())},
m(a,b){var t
if(a==null)a=new A.aY()
b.dartException=a
t=A.dS
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
dS(){return J.X(this.dartException)},
ck(a,b){throw A.m(a,b==null?new Error():b)},
dR(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.ck(A.db(a,b,c),t)},
db(a,b,c){var t,s,r,q,p,o,n,m,l
if(typeof b=="string")t=b
else{s="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
r=s.length
q=b
if(q>r){c=q/r|0
q%=r}t=s[q]}p=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
o=u.j.b(a)?"list":"ByteData"
n=a.$flags|0
m="a "
if((n&4)!==0)l="constant "
else if((n&2)!==0){l="unmodifiable "
m="an "}else l=(n&1)!==0?"fixed-length ":""
return new A.b_("'"+t+"': Cannot "+p+" "+m+l+o)},
cj(a){throw A.j(A.aQ(a))},
cz(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.aK().constructor.prototype):Object.create(new A.a_(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.bH(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.cv(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.bH(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
cv(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.j("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.ct)}throw A.j("Error in functionType of tearoff")},
cw(a,b,c,d){var t=A.bG
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
bH(a,b,c,d){if(c)return A.cy(a,b,d)
return A.cw(b.length,d,a,b)},
cx(a,b,c,d){var t=A.bG,s=A.cu
switch(b?-1:a){case 0:throw A.j(new A.aW("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
cy(a,b,c){var t,s
if($.bE==null)$.bE=A.bD("interceptor")
if($.bF==null)$.bF=A.bD("receiver")
t=b.length
s=A.cx(t,c,a,b)
return s},
bu(a){return A.cz(a)},
ct(a,b){return A.b4(v.typeUniverse,A.V(a.a),b)},
bG(a){return a.a},
cu(a){return a.b},
bD(a){var t,s,r,q=new A.a_("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.j(A.bC("Field name "+a+" not found."))},
bd(a){return v.getIsolateTag(a)},
dM(a){var t,s,r,q,p,o=A.S($.cf.$1(a)),n=$.bb[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.bj[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.br($.cc.$2(a,o))
if(r!=null){n=$.bb[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.bj[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.bk(t)
$.bb[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.bj[o]=t
return t}if(q==="-"){p=A.bk(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.ch(a,t)
if(q==="*")throw A.j(A.bP(o))
if(v.leafTags[o]===true){p=A.bk(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.ch(a,t)},
ch(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.bz(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
bk(a){return J.bz(a,!1,null,!!a.$ip)},
dO(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.bk(t)
else return J.bz(t,c,null,null)},
dG(){if(!0===$.by)return
$.by=!0
A.dH()},
dH(){var t,s,r,q,p,o,n,m
$.bb=Object.create(null)
$.bj=Object.create(null)
A.dF()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.ci.$1(p)
if(o!=null){n=A.dO(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
dF(){var t,s,r,q,p,o,n=B.f()
n=A.U(B.h,A.U(B.i,A.U(B.d,A.U(B.d,A.U(B.j,A.U(B.k,A.U(B.l(B.c),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.cf=new A.be(q)
$.cc=new A.bf(p)
$.ci=new A.bg(o)},
U(a,b){return a(b)||b},
dC(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
ac:function ac(){},
B:function B(){},
aq:function aq(){},
aL:function aL(){},
aK:function aK(){},
a_:function a_(a,b){this.a=a
this.b=b},
aW:function aW(a){this.a=a},
be:function be(a){this.a=a},
bf:function bf(a){this.a=a},
bg:function bg(a){this.a=a},
H(a,b,c){if(a>>>0!==a||a>=c)throw A.j(A.bv(b,a))},
P:function P(){},
a9:function a9(){},
ay:function ay(){},
Q:function Q(){},
a7:function a7(){},
a8:function a8(){},
az:function az(){},
aA:function aA(){},
aB:function aB(){},
aC:function aC(){},
aD:function aD(){},
aE:function aE(){},
aF:function aF(){},
aa:function aa(){},
aG:function aG(){},
af:function af(){},
ag:function ag(){},
ah:function ah(){},
ai:function ai(){},
bo(a,b){var t=b.c
return t==null?b.c=A.ak(a,"bI",[b.x]):t},
bN(a){var t=a.w
if(t===6||t===7)return A.bN(a.x)
return t===11||t===12},
cI(a){return a.as},
bw(a){return A.b3(v.typeUniverse,a,!1)},
J(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.J(a0,t,a2,a3)
if(s===t)return a1
return A.bW(a0,s,!0)
case 7:t=a1.x
s=A.J(a0,t,a2,a3)
if(s===t)return a1
return A.bV(a0,s,!0)
case 8:r=a1.y
q=A.T(a0,r,a2,a3)
if(q===r)return a1
return A.ak(a0,a1.x,q)
case 9:p=a1.x
o=A.J(a0,p,a2,a3)
n=a1.y
m=A.T(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.bp(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.T(a0,k,a2,a3)
if(j===k)return a1
return A.bX(a0,l,j)
case 11:i=a1.x
h=A.J(a0,i,a2,a3)
g=a1.y
f=A.dz(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.bU(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.T(a0,e,a2,a3)
p=a1.x
o=A.J(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.bq(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.j(A.ap("Attempted to substitute unexpected RTI kind "+a))}},
T(a,b,c,d){var t,s,r,q,p=b.length,o=A.b5(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.J(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
dA(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.b5(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.J(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
dz(a,b,c,d){var t,s=b.a,r=A.T(a,s,c,d),q=b.b,p=A.T(a,q,c,d),o=b.c,n=A.dA(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.aM()
t.a=r
t.b=p
t.c=n
return t},
I(a,b){a[v.arrayRti]=b
return a},
cd(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.dE(t)
return a.$S()}return null},
dJ(a,b){var t
if(A.bN(b))if(a instanceof A.B){t=A.cd(a)
if(t!=null)return t}return A.V(a)},
V(a){if(a instanceof A.h)return A.b7(a)
if(Array.isArray(a))return A.E(a)
return A.bs(J.ao(a))},
E(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
b7(a){var t=a.$ti
return t!=null?t:A.bs(a)},
bs(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.di(a,t)},
di(a,b){var t=a instanceof A.B?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.d2(v.typeUniverse,t.name)
b.$ccache=s
return s},
dE(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.b3(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
dD(a){return A.K(A.b7(a))},
dy(a){var t=a instanceof A.B?A.cd(a):null
if(t!=null)return t
if(u.R.b(a))return J.cs(a).a
if(Array.isArray(a))return A.E(a)
return A.V(a)},
K(a){var t=a.r
return t==null?a.r=new A.b2(a):t},
z(a){return A.K(A.b3(v.typeUniverse,a,!1))},
dh(a){var t=this
t.b=A.dx(t)
return t.b(a)},
dx(a){var t,s,r,q,p
if(a===u.K)return A.dp
if(A.L(a))return A.dt
t=a.w
if(t===6)return A.df
if(t===1)return A.c8
if(t===7)return A.dj
s=A.dw(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.L)){a.f="$i"+r
if(r==="d")return A.dm
if(a===u.m)return A.dl
return A.ds}}else if(t===10){q=A.dC(a.x,a.y)
p=q==null?A.c8:q
return p==null?A.c1(p):p}return A.dd},
dw(a){if(a.w===8){if(a===u.S)return A.c6
if(a===u.i||a===u.H)return A.dn
if(a===u.N)return A.dr
if(a===u.y)return A.bt}return null},
dg(a){var t=this,s=A.dc
if(A.L(t))s=A.d9
else if(t===u.K)s=A.c1
else if(A.W(t)){s=A.de
if(t===u.t)s=A.d7
else if(t===u.v)s=A.br
else if(t===u.u)s=A.d4
else if(t===u.n)s=A.c0
else if(t===u.I)s=A.d6
else if(t===u.z)s=A.G}else if(t===u.S)s=A.an
else if(t===u.N)s=A.S
else if(t===u.y)s=A.b6
else if(t===u.H)s=A.d8
else if(t===u.i)s=A.d5
else if(t===u.m)s=A.v
t.a=s
return t.a(a)},
dd(a){var t=this
if(a==null)return A.W(t)
return A.dL(v.typeUniverse,A.dJ(a,t),t)},
df(a){if(a==null)return!0
return this.x.b(a)},
ds(a){var t,s=this
if(a==null)return A.W(s)
t=s.f
if(a instanceof A.h)return!!a[t]
return!!J.ao(a)[t]},
dm(a){var t,s=this
if(a==null)return A.W(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.h)return!!a[t]
return!!J.ao(a)[t]},
dl(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.h)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
c7(a){if(typeof a=="object"){if(a instanceof A.h)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
dc(a){var t=this
if(a==null){if(A.W(t))return a}else if(t.b(a))return a
throw A.m(A.c2(a,t),new Error())},
de(a){var t=this
if(a==null||t.b(a))return a
throw A.m(A.c2(a,t),new Error())},
c2(a,b){return new A.aN("TypeError: "+A.bQ(a,A.r(b,null)))},
bQ(a,b){return A.aS(a)+": type '"+A.r(A.dy(a),null)+"' is not a subtype of type '"+b+"'"},
u(a,b){return new A.aN("TypeError: "+A.bQ(a,b))},
dj(a){var t=this
return t.x.b(a)||A.bo(v.typeUniverse,t).b(a)},
dp(a){return a!=null},
c1(a){if(a!=null)return a
throw A.m(A.u(a,"Object"),new Error())},
dt(a){return!0},
d9(a){return a},
c8(a){return!1},
bt(a){return!0===a||!1===a},
b6(a){if(!0===a)return!0
if(!1===a)return!1
throw A.m(A.u(a,"bool"),new Error())},
d4(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.m(A.u(a,"bool?"),new Error())},
d5(a){if(typeof a=="number")return a
throw A.m(A.u(a,"double"),new Error())},
d6(a){if(typeof a=="number")return a
if(a==null)return a
throw A.m(A.u(a,"double?"),new Error())},
c6(a){return typeof a=="number"&&Math.floor(a)===a},
an(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.m(A.u(a,"int"),new Error())},
d7(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.m(A.u(a,"int?"),new Error())},
dn(a){return typeof a=="number"},
d8(a){if(typeof a=="number")return a
throw A.m(A.u(a,"num"),new Error())},
c0(a){if(typeof a=="number")return a
if(a==null)return a
throw A.m(A.u(a,"num?"),new Error())},
dr(a){return typeof a=="string"},
S(a){if(typeof a=="string")return a
throw A.m(A.u(a,"String"),new Error())},
br(a){if(typeof a=="string")return a
if(a==null)return a
throw A.m(A.u(a,"String?"),new Error())},
v(a){if(A.c7(a))return a
throw A.m(A.u(a,"JSObject"),new Error())},
G(a){if(a==null)return a
if(A.c7(a))return a
throw A.m(A.u(a,"JSObject?"),new Error())},
cb(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.r(a[r],b)
return t},
dv(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.cb(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.r(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
c3(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.I([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.m(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.t(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.r(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.r(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.r(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.r(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.r(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
r(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.r(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.r(a.x,b)+">"
if(m===8){q=A.dB(a.x)
p=a.y
return p.length>0?q+("<"+A.cb(p,b)+">"):q}if(m===10)return A.dv(a,b)
if(m===11)return A.c3(a,b,null)
if(m===12)return A.c3(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.t(b,o)
return b[o]}return"?"},
dB(a){var t=A.cl(a)
if(t!=null)return t
return"minified:"+a},
d3(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
d2(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.b3(a,b,!1)
else if(typeof n=="number"){t=n
s=A.al(a,5,"#")
r=A.b5(t)
for(q=0;q<t;++q)r[q]=s
p=A.ak(a,b,r)
o[b]=p
return p}else return n},
d0(a,b){return A.bZ(a.tR,b)},
d_(a,b){return A.bZ(a.eT,b)},
b3(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.bY(a,null,b,!1)
s.set(b,t)
return t},
b4(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.bY(a,b,c,!0)
r.set(c,s)
return s},
d1(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.bp(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
bY(a,b,c,d){return A.cT(A.cN(a,b,c,d))},
D(a,b){b.a=A.dg
b.b=A.dh
return b},
al(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.x(null,null)
t.w=b
t.as=c
s=A.D(a,t)
a.eC.set(c,s)
return s},
bW(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.cY(a,b,s,c)
a.eC.set(s,t)
return t},
cY(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.L(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.W(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.x(null,null)
r.w=6
r.x=b
r.as=c
return A.D(a,r)},
bV(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.cW(a,b,s,c)
a.eC.set(s,t)
return t},
cW(a,b,c,d){var t,s
if(d){t=b.w
if(A.L(b)||b===u.K)return b
else if(t===1)return A.ak(a,"bI",[b])
else if(b===u.P||b===u.T)return u.Q}s=new A.x(null,null)
s.w=7
s.x=b
s.as=c
return A.D(a,s)},
cZ(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.x(null,null)
t.w=13
t.x=b
t.as=r
s=A.D(a,t)
a.eC.set(r,s)
return s},
aj(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
cV(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
ak(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.aj(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.x(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.D(a,s)
a.eC.set(q,r)
return r},
bp(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.aj(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.x(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.D(a,p)
a.eC.set(r,o)
return o},
bX(a,b,c){var t,s,r="+"+(b+"("+A.aj(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.x(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.D(a,t)
a.eC.set(r,s)
return s},
bU(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.aj(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.aj(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.cV(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.x(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.D(a,q)
a.eC.set(s,p)
return p},
bq(a,b,c,d){var t,s=b.as+("<"+A.aj(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.cX(a,b,c,s,d)
a.eC.set(s,t)
return t},
cX(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.b5(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.J(a,b,s,0)
n=A.T(a,c,s,0)
return A.bq(a,o,n,c!==n)}}m=new A.x(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.D(a,m)},
cN(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
cT(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.cP(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.bS(a,s,m,l,!1)
else if(r===46)s=A.bS(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.F(a.u,a.e,l.pop()))
break
case 94:l.push(A.cZ(a.u,l.pop()))
break
case 35:l.push(A.al(a.u,5,"#"))
break
case 64:l.push(A.al(a.u,2,"@"))
break
case 126:l.push(A.al(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.cR(a,l)
break
case 38:A.cQ(a,l)
break
case 63:q=a.u
l.push(A.bW(q,A.F(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.bV(q,A.F(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.cO(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.bT(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.cU(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-2)
break
case 43:o=m.indexOf("(",s)
l.push(m.substring(s,o))
l.push(-4)
l.push(a.p)
a.p=l.length
s=o+1
break
default:throw"Bad character "+r}}}n=l.pop()
return A.F(a.u,a.e,n)},
cP(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
bS(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.d3(t,p.x)[q]
if(o==null)A.ck('No "'+q+'" in "'+A.cI(p)+'"')
d.push(A.b4(t,p,o))}else d.push(q)
return n},
cR(a,b){var t,s=a.u,r=A.bR(a,b),q=b.pop()
if(typeof q=="string")b.push(A.ak(s,q,r))
else{t=A.F(s,a.e,q)
switch(t.w){case 11:b.push(A.bq(s,t,r,a.n))
break
default:b.push(A.bp(s,t,r))
break}}},
cO(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.bR(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.F(q,a.e,p)
r=new A.aM()
r.a=t
r.b=o
r.c=n
b.push(A.bU(q,s,r))
return
case-4:b.push(A.bX(q,b.pop(),t))
return
default:throw A.j(A.ap("Unexpected state under `()`: "+A.o(p)))}},
cQ(a,b){var t=b.pop()
if(0===t){b.push(A.al(a.u,1,"0&"))
return}if(1===t){b.push(A.al(a.u,4,"1&"))
return}throw A.j(A.ap("Unexpected extended operation "+A.o(t)))},
bR(a,b){var t=b.splice(a.p)
A.bT(a.u,a.e,t)
a.p=b.pop()
return t},
F(a,b,c){if(typeof c=="string")return A.ak(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.cS(a,b,c)}else return c},
bT(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.F(a,b,c[t])},
cU(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.F(a,b,c[t])},
cS(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.j(A.ap("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.j(A.ap("Bad index "+c+" for "+b.h(0)))},
dL(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.k(a,b,null,c,null)
s.set(c,t)}return t},
k(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.L(d))return!0
t=b.w
if(t===4)return!0
if(A.L(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.k(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.k(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.k(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.k(a,b.x,c,d,e))return!1
return A.k(a,A.bo(a,b),c,d,e)}if(t===6)return A.k(a,q,c,d,e)&&A.k(a,b.x,c,d,e)
if(r===7){if(A.k(a,b,c,d.x,e))return!0
return A.k(a,b,c,A.bo(a,d),e)}if(r===6)return A.k(a,b,c,q,e)||A.k(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.L)return!0
if(r===12){if(b===u.g)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.k(a,k,c,j,e)||!A.k(a,j,e,k,c))return!1}return A.c5(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.c5(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.dk(a,b,c,d,e)}if(p&&r===10)return A.dq(a,b,c,d,e)
return!1},
c5(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.k(a2,a3.x,a4,a5.x,a6))return!1
t=a3.y
s=a5.y
r=t.a
q=s.a
p=r.length
o=q.length
if(p>o)return!1
n=o-p
m=t.b
l=s.b
k=m.length
j=l.length
if(p+k<o+j)return!1
for(i=0;i<p;++i){h=r[i]
if(!A.k(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.k(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.k(a2,l[i],a6,h,a4))return!1}g=t.c
f=s.c
e=g.length
d=f.length
for(c=0,b=0;b<d;b+=3){a=f[b]
for(;;){if(c>=e)return!1
a0=g[c]
c+=3
if(a<a0)return!1
a1=g[c-2]
if(a0<a){if(a1)return!1
continue}h=f[b+1]
if(a1&&!h)return!1
h=g[c-1]
if(!A.k(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
dk(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.b4(a,b,s[p])
return A.c_(a,q,null,c,d.y,e)}return A.c_(a,b.y,null,c,d.y,e)},
c_(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.k(a,b[t],d,e[t],f))return!1
return!0},
dq(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.k(a,s[t],c,r[t],e))return!1
return!0},
W(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.L(a))if(t!==6)s=t===7&&A.W(a.x)
return s},
L(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
bZ(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
b5(a){return a>0?new Array(a):v.typeUniverse.sEA},
x:function x(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
aM:function aM(){this.c=this.b=this.a=null},
b2:function b2(a){this.a=a},
b0:function b0(){},
aN:function aN(a){this.a=a},
e:function e(){},
bO(a,b,c){var t=J.bB(b)
if(!t.l())return a
if(c.length===0){do a+=A.o(t.gn())
while(t.l())}else{a+=A.o(t.gn())
while(t.l())a=a+c+A.o(t.gn())}return a},
aS(a){if(typeof a=="number"||A.bt(a)||a==null)return J.X(a)
if(typeof a=="string")return JSON.stringify(a)
return A.cG(a)},
ap(a){return new A.aO(a)},
bC(a){return new A.Y(!1,null,null,a)},
bM(a,b,c,d,e){return new A.aJ(b,c,!0,a,d,"Invalid value")},
cH(a,b){return a},
bJ(a,b,c,d){return new A.aT(b,!0,a,d,"Index out of range")},
bP(a){return new A.aZ(a)},
aQ(a){return new A.aP(a)},
cF(a,b,c){var t,s
if(A.cg(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.I([],u.s)
B.a.m($.A,a)
try{A.du(a,t)}finally{if(0>=$.A.length)return A.t($.A,-1)
$.A.pop()}s=A.bO(b,u.U.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
bK(a,b,c){var t,s
if(A.cg(a))return b+"..."+c
t=new A.aX(b)
B.a.m($.A,a)
try{s=t
s.a=A.bO(s.a,a,", ")}finally{if(0>=$.A.length)return A.t($.A,-1)
$.A.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
du(a,b){var t,s,r,q,p,o,n,m=a.gq(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.l())return
t=A.o(m.gn())
B.a.m(b,t)
l+=t.length+2;++k}if(!m.l()){if(k<=5)return
if(0>=b.length)return A.t(b,-1)
s=b.pop()
if(0>=b.length)return A.t(b,-1)
r=b.pop()}else{q=m.gn();++k
if(!m.l()){if(k<=4){B.a.m(b,A.o(q))
return}s=A.o(q)
if(0>=b.length)return A.t(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gn();++k
for(;m.l();q=p,p=o){o=m.gn();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.t(b,-1)
l-=b.pop().length+2;--k}B.a.m(b,"...")
return}}r=A.o(q)
s=A.o(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.t(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.m(b,n)
B.a.m(b,r)
B.a.m(b,s)},
aR:function aR(){},
aO:function aO(a){this.a=a},
aY:function aY(){},
Y:function Y(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aJ:function aJ(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
aT:function aT(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
b_:function b_(a){this.a=a},
aZ:function aZ(a){this.a=a},
aP:function aP(a){this.a=a},
b:function b(){},
ab:function ab(){},
h:function h(){},
aX:function aX(a){this.a=a},
c9(a){var t,s
if(a!=null){t=A.bm(a,"Element")
t=!t}else t=!0
if(t)return!1
A.v(a)
if(A.S(a.tagName)!=="FLT-SEMANTICS")return!1
s=A.br(a.getAttribute("flt-semantics-identifier"))
if(s!=null&&B.n.F(s,"beui-tooltip-"))return!0
t=u.c.a(a.getAttributeNames())
t=u.a.b(t)?t:new A.a1(t,A.E(t).p("a1<1,q>"))
return J.cr(t,new A.b8())&&A.an(A.v(a.childNodes).length)===1&&A.c9(A.G(A.v(a.childNodes).item(0)))},
ca(a,b,c,d){var t,s,r,q,p,o,n,m,l,k,j=!0
if(b!=null)if(c!=null){t=A.bm(b,"Element")
if(t){j=A.bm(c,"Element")
j=!j}}if(j)return!1
A.v(b)
A.v(c)
if(A.S(b.tagName)!=="FLT-SEMANTICS"||A.S(c.tagName)!=="FLT-SEMANTICS"||!A.b6(b.isConnected)||!A.b6(c.isConnected)||A.G(c.parentElement)!==b||A.G(b.closest("flutter-view"))==null)return!1
s=A.G(A.v(b.ownerDocument).activeElement)
if(s==null||!A.b6(c.contains(s)))return!1
r=A.I([],u.O)
for(q=0;q<A.an(A.v(b.childNodes).length);++q){j=A.G(A.v(b.childNodes).item(q))
j.toString
B.a.m(r,j)}p=B.a.E(r,new A.b9(c))
o=d==null?r.length:B.a.E(r,new A.ba(d))
if(p<0||o<0)return!1
if(p===o||o===p+1)return!1
j=o<p
n=j?B.a.D(r,o,p):B.a.D(r,p+1,o)
if(!B.a.B(n,A.dP()))return!1
m=j?A.G(c.nextSibling):c
for(j=n.length,t=v.G,l=0;l<n.length;n.length===j||(0,A.cj)(n),++l){k=n[l]
t.Reflect.apply(a,b,[k,m])}return!0},
dI(){var t,s,r,q=v.G
if(A.v(q.globalThis).__beuiTooltipSemanticsMoveGuardV1!=null)return
t=u.g
s=t.a(q.Node.prototype.insertBefore)
r=t.a(q.Element.prototype.append)
q.Node.prototype.insertBefore=t.a(new q.Proxy(s,{apply:A.c4(new A.bh(s))}))
q.Element.prototype.append=t.a(new q.Proxy(r,{apply:A.c4(new A.bi(s))}))
A.v(q.globalThis).__beuiTooltipSemanticsMoveGuardV1=!0},
b8:function b8(){},
b9:function b9(a){this.a=a},
ba:function ba(a){this.a=a},
bh:function bh(a){this.a=a},
bi:function bi(a){this.a=a},
cl(a){return v.mangledGlobalNames[a]},
dQ(a){throw A.m(new A.aV("Field '"+a+"' has been assigned during initialization."),new Error())},
bm(a,b){var t,s,r,q,p
if(b.length===0)return!1
t=b.split(".")
s=v.G
for(r=t.length,q=0;q<r;++q,s=p){p=s[t[q]]
A.G(p)
if(p==null)return!1}return a instanceof u.g.a(s)},
c4(a){var t
if(typeof a=="function")throw A.j(A.bC("Attempting to rewrap a JS function."))
t=function(b,c){return function(d,e,f){return b(c,d,e,f,arguments.length)}}(A.da,a)
t[$.bA()]=a
return t},
da(a,b,c,d,e){u.Z.a(a)
A.an(e)
if(e>=3)return a.$3(b,c,d)
if(e===2)return a.$2(b,c)
if(e===1)return a.$1(b)
return a.$0()},
dN(){return A.dI()}},B={}
var w=[A,J,B]
var $={}
A.bn.prototype={}
J.ar.prototype={
h(a){return"Instance of '"+A.aI(a)+"'"},
gi(a){return A.K(A.bs(this))}}
J.au.prototype={
h(a){return String(a)},
gi(a){return A.K(u.y)},
$ic:1,
$iw:1}
J.a2.prototype={
h(a){return"null"},
$ic:1}
J.a4.prototype={$ii:1}
J.C.prototype={
h(a){return String(a)}}
J.aH.prototype={}
J.ad.prototype={}
J.y.prototype={
h(a){var t=a[$.cn()]
if(t==null)t=a[$.bA()]
if(t==null)return this.H(a)
return"JavaScript function for "+J.X(t)},
$iN:1}
J.a3.prototype={
h(a){return String(a)}}
J.a5.prototype={
h(a){return String(a)}}
J.l.prototype={
m(a,b){A.E(a).c.a(b)
a.$flags&1&&A.dR(a,29)
a.push(b)},
t(a,b){if(!(b<a.length))return A.t(a,b)
return a[b]},
D(a,b,c){if(b<0||b>a.length)throw A.j(A.bM(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.j(A.bM(c,b,a.length,"end",null))
if(b===c)return A.I([],A.E(a))
return A.I(a.slice(b,c),A.E(a))},
B(a,b){var t,s
A.E(a).p("w(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(!b.$1(a[s]))return!1
if(a.length!==t)throw A.j(A.aQ(a))}return!0},
h(a){return A.bK(a,"[","]")},
gq(a){return new J.Z(a,a.length,A.E(a).p("Z<1>"))},
gj(a){return a.length},
k(a,b){if(!(b>=0&&b<a.length))throw A.j(A.bv(a,b))
return a[b]},
E(a,b){var t
A.E(a).p("w(1)").a(b)
if(0>=a.length)return-1
for(t=0;t<a.length;++t)if(b.$1(a[t]))return t
return-1},
$ib:1,
$id:1}
J.at.prototype={
I(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.aI(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.aU.prototype={}
J.Z.prototype={
gn(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.cj(r)
throw A.j(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$ias:1}
J.ax.prototype={
h(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gi(a){return A.K(u.H)},
$if:1,
$iM:1}
J.av.prototype={
gi(a){return A.K(u.S)},
$ic:1,
$ia:1}
J.aw.prototype={
gi(a){return A.K(u.i)},
$ic:1}
J.O.prototype={
F(a,b){var t=b.length
if(t>a.length)return!1
return b===a.substring(0,t)},
h(a){return a},
gi(a){return A.K(u.N)},
gj(a){return a.length},
$ic:1,
$ibL:1,
$iq:1}
A.R.prototype={
gq(a){return new A.a0(J.bB(this.gu()),A.b7(this).p("a0<1,2>"))},
gj(a){return J.bl(this.gu())},
t(a,b){return A.b7(this).y[1].a(J.cq(this.gu(),b))},
h(a){return J.X(this.gu())}}
A.a0.prototype={
l(){return this.a.l()},
gn(){return this.$ti.y[1].a(this.a.gn())},
$ias:1}
A.ae.prototype={
k(a,b){return this.$ti.y[1].a(J.cp(this.a,b))},
$id:1}
A.a1.prototype={
gu(){return this.a}}
A.aV.prototype={
h(a){return"LateInitializationError: "+this.a}}
A.a6.prototype={
gn(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t,s=this,r=s.a,q=J.ce(r),p=q.gj(r)
if(s.b!==p)throw A.j(A.aQ(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.t(r,t);++s.c
return!0},
$ias:1}
A.n.prototype={}
A.am.prototype={}
A.ac.prototype={}
A.B.prototype={
h(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.cm(s==null?"unknown":s)+"'"},
$iN:1,
gJ(){return this},
$C:"$1",
$R:1,
$D:null}
A.aq.prototype={$C:"$2",$R:2}
A.aL.prototype={}
A.aK.prototype={
h(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.cm(t)+"'"}}
A.a_.prototype={
h(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.aI(this.a)+"'")}}
A.aW.prototype={
h(a){return"RuntimeError: "+this.a}}
A.be.prototype={
$1(a){return this.a(a)},
$S:2}
A.bf.prototype={
$2(a,b){return this.a(a,b)},
$S:3}
A.bg.prototype={
$1(a){return this.a(A.S(a))},
$S:4}
A.P.prototype={
gi(a){return B.q},
$ic:1}
A.a9.prototype={}
A.ay.prototype={
gi(a){return B.r},
$ic:1}
A.Q.prototype={
gj(a){return a.length},
$ip:1}
A.a7.prototype={
k(a,b){A.H(b,a,a.length)
return a[b]},
$ib:1,
$id:1}
A.a8.prototype={$ib:1,$id:1}
A.az.prototype={
gi(a){return B.t},
$ic:1}
A.aA.prototype={
gi(a){return B.u},
$ic:1}
A.aB.prototype={
gi(a){return B.v},
k(a,b){A.H(b,a,a.length)
return a[b]},
$ic:1}
A.aC.prototype={
gi(a){return B.w},
k(a,b){A.H(b,a,a.length)
return a[b]},
$ic:1}
A.aD.prototype={
gi(a){return B.x},
k(a,b){A.H(b,a,a.length)
return a[b]},
$ic:1}
A.aE.prototype={
gi(a){return B.y},
k(a,b){A.H(b,a,a.length)
return a[b]},
$ic:1}
A.aF.prototype={
gi(a){return B.z},
k(a,b){A.H(b,a,a.length)
return a[b]},
$ic:1}
A.aa.prototype={
gi(a){return B.A},
gj(a){return a.length},
k(a,b){A.H(b,a,a.length)
return a[b]},
$ic:1}
A.aG.prototype={
gi(a){return B.B},
gj(a){return a.length},
k(a,b){A.H(b,a,a.length)
return a[b]},
$ic:1}
A.af.prototype={}
A.ag.prototype={}
A.ah.prototype={}
A.ai.prototype={}
A.x.prototype={
p(a){return A.b4(v.typeUniverse,this,a)},
K(a){return A.d1(v.typeUniverse,this,a)}}
A.aM.prototype={}
A.b2.prototype={
h(a){return A.r(this.a,null)}}
A.b0.prototype={
h(a){return this.a}}
A.aN.prototype={}
A.e.prototype={
gq(a){return new A.a6(a,this.gj(a),A.V(a).p("a6<e.E>"))},
t(a,b){return this.k(a,b)},
B(a,b){var t,s
A.V(a).p("w(e.E)").a(b)
t=this.gj(a)
for(s=0;s<t;++s){if(!b.$1(this.k(a,s)))return!1
if(t!==this.gj(a))throw A.j(A.aQ(a))}return!0},
h(a){return A.bK(a,"[","]")}}
A.aR.prototype={}
A.aO.prototype={
h(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.aS(t)
return"Assertion failed"}}
A.aY.prototype={}
A.Y.prototype={
gA(){return"Invalid argument"+(!this.a?"(s)":"")},
gv(){return""},
h(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.gA()+r+p
if(!t.a)return o
return o+t.gv()+": "+A.aS(t.gC())},
gC(){return this.b}}
A.aJ.prototype={
gC(){return A.c0(this.b)},
gA(){return"RangeError"},
gv(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.o(r):""
else if(r==null)t=": Not greater than or equal to "+A.o(s)
else if(r>s)t=": Not in inclusive range "+A.o(s)+".."+A.o(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.o(s)
return t}}
A.aT.prototype={
gC(){return A.an(this.b)},
gA(){return"RangeError"},
gv(){if(A.an(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gj(a){return this.f}}
A.b_.prototype={
h(a){return"Unsupported operation: "+this.a}}
A.aZ.prototype={
h(a){return"UnimplementedError: "+this.a}}
A.aP.prototype={
h(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.aS(t)+"."}}
A.b.prototype={
gj(a){var t,s=this.gq(this)
for(t=0;s.l();)++t
return t},
t(a,b){var t,s
A.cH(b,"index")
t=this.gq(this)
for(s=b;t.l();)s=s.G(0,1)
throw A.j(A.bJ(b,b.G(0,s),this,"index"))},
h(a){return A.cF(this,"(",")")}}
A.ab.prototype={
h(a){return"null"}}
A.h.prototype={$ih:1,
h(a){return"Instance of '"+A.aI(this)+"'"},
gi(a){return A.dD(this)},
toString(){return this.h(this)}}
A.aX.prototype={
gj(a){return this.a.length},
h(a){var t=this.a
return t.charCodeAt(0)==0?t:t}}
A.b8.prototype={
$1(a){A.S(a)
return a==="id"||a==="style"},
$S:5}
A.b9.prototype={
$1(a){return A.v(a)===this.a},
$S:0}
A.ba.prototype={
$1(a){return A.v(a)===this.a},
$S:0}
A.bh.prototype={
$3(a,b,c){var t
u.g.a(a)
u.c.a(c)
if(c.length>=2){if(0<0||0>=c.length)return A.t(c,0)
t=c[0]
if(1<0||1>=c.length)return A.t(c,1)
t=A.ca(this.a,b,t,c[1])}else t=!1
if(t){if(0<0||0>=c.length)return A.t(c,0)
return c[0]}return v.G.Reflect.apply(a,b,c)},
$S:1}
A.bi.prototype={
$3(a,b,c){var t
u.g.a(a)
u.c.a(c)
if(c.length===1){if(0<0||0>=c.length)return A.t(c,0)
t=A.ca(this.a,b,c[0],null)}else t=!1
if(t)return v.G.undefined
return v.G.Reflect.apply(a,b,c)},
$S:1};(function aliases(){var t=J.C.prototype
t.H=t.h})();(function installTearOffs(){var t=hunkHelpers._static_1
t(A,"dP","c9",6)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.h,null)
r(A.h,[A.bn,J.ar,A.ac,J.Z,A.b,A.a0,A.aR,A.a6,A.n,A.B,A.x,A.aM,A.b2,A.e,A.ab,A.aX])
r(J.ar,[J.au,J.a2,J.a4,J.a3,J.a5,J.ax,J.O])
r(J.a4,[J.C,J.l,A.P,A.a9])
r(J.C,[J.aH,J.ad,J.y])
s(J.at,A.ac)
s(J.aU,J.l)
r(J.ax,[J.av,J.aw])
s(A.R,A.b)
s(A.am,A.R)
s(A.ae,A.am)
s(A.a1,A.ae)
r(A.aR,[A.aV,A.aW,A.b0,A.aO,A.aY,A.Y,A.b_,A.aZ,A.aP])
r(A.B,[A.aq,A.aL,A.be,A.bg,A.b8,A.b9,A.ba,A.bh,A.bi])
r(A.aL,[A.aK,A.a_])
s(A.bf,A.aq)
r(A.a9,[A.ay,A.Q])
r(A.Q,[A.af,A.ah])
s(A.ag,A.af)
s(A.a7,A.ag)
s(A.ai,A.ah)
s(A.a8,A.ai)
r(A.a7,[A.az,A.aA])
r(A.a8,[A.aB,A.aC,A.aD,A.aE,A.aF,A.aa,A.aG])
s(A.aN,A.b0)
r(A.Y,[A.aJ,A.aT])
t(A.am,A.e)
t(A.af,A.e)
t(A.ag,A.n)
t(A.ah,A.e)
t(A.ai,A.n)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",f:"double",M:"num",q:"String",w:"bool",ab:"Null",d:"List",h:"Object",dX:"Map",i:"JSObject"},mangledNames:{},types:["w(i)","h?(y,h?,l<h?>)","@(@)","@(@,q)","@(q)","w(q)","w(h?)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti")}
A.d0(v.typeUniverse,JSON.parse('{"y":"C","aH":"C","ad":"C","dY":"P","l":{"d":["1"],"i":[],"b":["1"]},"au":{"w":[],"c":[]},"a2":{"c":[]},"a4":{"i":[]},"C":{"i":[]},"at":{"ac":[]},"aU":{"l":["1"],"d":["1"],"i":[],"b":["1"]},"Z":{"as":["1"]},"ax":{"f":[],"M":[]},"av":{"f":[],"a":[],"M":[],"c":[]},"aw":{"f":[],"M":[],"c":[]},"O":{"q":[],"bL":[],"c":[]},"R":{"b":["2"]},"a0":{"as":["2"]},"ae":{"e":["2"],"d":["2"],"R":["1","2"],"b":["2"]},"a1":{"ae":["1","2"],"e":["2"],"d":["2"],"R":["1","2"],"b":["2"],"e.E":"2"},"a6":{"as":["1"]},"B":{"N":[]},"aq":{"N":[]},"aL":{"N":[]},"aK":{"N":[]},"a_":{"N":[]},"P":{"i":[],"c":[]},"a9":{"i":[]},"ay":{"i":[],"c":[]},"Q":{"p":["1"],"i":[]},"a7":{"e":["f"],"d":["f"],"p":["f"],"i":[],"b":["f"],"n":["f"]},"a8":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"]},"az":{"e":["f"],"d":["f"],"p":["f"],"i":[],"b":["f"],"n":["f"],"c":[],"e.E":"f"},"aA":{"e":["f"],"d":["f"],"p":["f"],"i":[],"b":["f"],"n":["f"],"c":[],"e.E":"f"},"aB":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"],"c":[],"e.E":"a"},"aC":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"],"c":[],"e.E":"a"},"aD":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"],"c":[],"e.E":"a"},"aE":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"],"c":[],"e.E":"a"},"aF":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"],"c":[],"e.E":"a"},"aa":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"],"c":[],"e.E":"a"},"aG":{"e":["a"],"d":["a"],"p":["a"],"i":[],"b":["a"],"n":["a"],"c":[],"e.E":"a"},"f":{"M":[]},"a":{"M":[]},"q":{"bL":[]},"cE":{"d":["a"],"b":["a"]},"cM":{"d":["a"],"b":["a"]},"cL":{"d":["a"],"b":["a"]},"cC":{"d":["a"],"b":["a"]},"cJ":{"d":["a"],"b":["a"]},"cD":{"d":["a"],"b":["a"]},"cK":{"d":["a"],"b":["a"]},"cA":{"d":["f"],"b":["f"]},"cB":{"d":["f"],"b":["f"]}}'))
A.d_(v.typeUniverse,JSON.parse('{"am":2,"Q":1}'))
var u=(function rtii(){var t=A.bw
return{Z:t("N"),U:t("b<@>"),O:t("l<i>"),s:t("l<q>"),b:t("l<@>"),c:t("l<h?>"),T:t("a2"),m:t("i"),g:t("y"),p:t("p<@>"),a:t("d<q>"),j:t("d<@>"),P:t("ab"),K:t("h"),L:t("dZ"),N:t("q"),R:t("c"),o:t("ad"),y:t("w"),i:t("f"),S:t("a"),Q:t("bI<ab>?"),z:t("i?"),X:t("h?"),v:t("q?"),u:t("w?"),I:t("f?"),t:t("a?"),n:t("M?"),H:t("M")}})();(function constants(){B.m=J.ar.prototype
B.a=J.l.prototype
B.n=J.O.prototype
B.o=J.y.prototype
B.p=J.a4.prototype
B.e=J.aH.prototype
B.b=J.ad.prototype
B.c=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.f=function() {
  var toStringFunction = Object.prototype.toString;
  function getTag(o) {
    var s = toStringFunction.call(o);
    return s.substring(8, s.length - 1);
  }
  function getUnknownTag(object, tag) {
    if (/^HTML[A-Z].*Element$/.test(tag)) {
      var name = toStringFunction.call(object);
      if (name == "[object Object]") return null;
      return "HTMLElement";
    }
  }
  function getUnknownTagGenericBrowser(object, tag) {
    if (object instanceof HTMLElement) return "HTMLElement";
    return getUnknownTag(object, tag);
  }
  function prototypeForTag(tag) {
    if (typeof window == "undefined") return null;
    if (typeof window[tag] == "undefined") return null;
    var constructor = window[tag];
    if (typeof constructor != "function") return null;
    return constructor.prototype;
  }
  function discriminator(tag) { return null; }
  var isBrowser = typeof HTMLElement == "function";
  return {
    getTag: getTag,
    getUnknownTag: isBrowser ? getUnknownTagGenericBrowser : getUnknownTag,
    prototypeForTag: prototypeForTag,
    discriminator: discriminator };
}
B.l=function(getTagFallback) {
  return function(hooks) {
    if (typeof navigator != "object") return hooks;
    var userAgent = navigator.userAgent;
    if (typeof userAgent != "string") return hooks;
    if (userAgent.indexOf("DumpRenderTree") >= 0) return hooks;
    if (userAgent.indexOf("Chrome") >= 0) {
      function confirm(p) {
        return typeof window == "object" && window[p] && window[p].name == p;
      }
      if (confirm("Window") && confirm("HTMLElement")) return hooks;
    }
    hooks.getTag = getTagFallback;
  };
}
B.h=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.k=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Firefox") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "GeoGeolocation": "Geolocation",
    "Location": "!Location",
    "WorkerMessageEvent": "MessageEvent",
    "XMLDocument": "!Document"};
  function getTagFirefox(o) {
    var tag = getTag(o);
    return quickMap[tag] || tag;
  }
  hooks.getTag = getTagFirefox;
}
B.j=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Trident/") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "HTMLDDElement": "HTMLElement",
    "HTMLDTElement": "HTMLElement",
    "HTMLPhraseElement": "HTMLElement",
    "Position": "Geoposition"
  };
  function getTagIE(o) {
    var tag = getTag(o);
    var newTag = quickMap[tag];
    if (newTag) return newTag;
    if (tag == "Object") {
      if (window.DataView && (o instanceof window.DataView)) return "DataView";
    }
    return tag;
  }
  function prototypeForTagIE(tag) {
    var constructor = window[tag];
    if (constructor == null) return null;
    return constructor.prototype;
  }
  hooks.getTag = getTagIE;
  hooks.prototypeForTag = prototypeForTagIE;
}
B.i=function(hooks) {
  var getTag = hooks.getTag;
  var prototypeForTag = hooks.prototypeForTag;
  function getTagFixed(o) {
    var tag = getTag(o);
    if (tag == "Document") {
      if (!!o.xmlVersion) return "!Document";
      return "!HTMLDocument";
    }
    return tag;
  }
  function prototypeForTagFixed(tag) {
    if (tag == "Document") return null;
    return prototypeForTag(tag);
  }
  hooks.getTag = getTagFixed;
  hooks.prototypeForTag = prototypeForTagFixed;
}
B.d=function(hooks) { return hooks; }

B.q=A.z("dT")
B.r=A.z("dU")
B.t=A.z("cA")
B.u=A.z("cB")
B.v=A.z("cC")
B.w=A.z("cD")
B.x=A.z("cE")
B.y=A.z("cJ")
B.z=A.z("cK")
B.A=A.z("cL")
B.B=A.z("cM")})();(function staticFields(){$.b1=null
$.A=A.I([],A.bw("l<h>"))
$.bF=null
$.bE=null
$.cf=null
$.cc=null
$.ci=null
$.bb=null
$.bj=null
$.by=null})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"dW","cn",()=>A.bd("_$dart_dartClosure"))
t($,"dV","bA",()=>A.bd("_$dart_dartClosure_dartJSInterop"))
t($,"e_","co",()=>A.I([new J.at()],A.bw("l<ac>")))})();(function nativeSupport(){!function(){var t=function(a){var n={}
n[a]=1
return Object.keys(hunkHelpers.convertToFastObject(n))[0]}
v.getIsolateTag=function(a){return t("___dart_"+a+v.isolateTag)}
var s="___dart_isolate_tags_"
var r=Object[s]||(Object[s]=Object.create(null))
var q="_ZxYxX"
for(var p=0;;p++){var o=t(q+"_"+p+"_")
if(!(o in r)){r[o]=1
v.isolateTag=o
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.P,SharedArrayBuffer:A.P,ArrayBufferView:A.a9,DataView:A.ay,Float32Array:A.az,Float64Array:A.aA,Int16Array:A.aB,Int32Array:A.aC,Int8Array:A.aD,Uint16Array:A.aE,Uint32Array:A.aF,Uint8ClampedArray:A.aa,CanvasPixelArray:A.aa,Uint8Array:A.aG})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.Q.$nativeSuperclassTag="ArrayBufferView"
A.af.$nativeSuperclassTag="ArrayBufferView"
A.ag.$nativeSuperclassTag="ArrayBufferView"
A.a7.$nativeSuperclassTag="ArrayBufferView"
A.ah.$nativeSuperclassTag="ArrayBufferView"
A.ai.$nativeSuperclassTag="ArrayBufferView"
A.a8.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.dN
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
//# sourceMappingURL=beui-semantics-guard-r4.js.map
