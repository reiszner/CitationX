### tire rotation per minute by circumference ####
#var tire=TireSpeed.new(# of gear,diam[0],diam[1],diam[2], ...);

props.globals.initNode("controls/flight/flaps-select",0,"INT");
var flaps_select = "controls/flight/flaps-select";

var TireSpeed = {
    new : func(number){
        m = { parents : [TireSpeed] };
            m.num=number;
            m.circumference=[];
            m.tire=[];
            m.rpm=[];
            for(var i=0; i<m.num; i+=1) {
                var diam =arg[i];
                var circ=diam * math.pi;
                append(m.circumference,circ);
                append(m.tire,props.globals.initNode("gear/gear["~i~"]/tire-rpm",0,"DOUBLE"));
                append(m.rpm,0);
            }
        m.count = 0;
        return m;
    },
    #### calculate and write rpm ###########
    get_rotation: func (fdm1){
        var speed=0;
        if(fdm1=="yasim"){
            speed =getprop("gear/gear["~me.count~"]/rollspeed-ms") or 0;
            speed=speed*60;
            }elsif(fdm1=="jsb"){
                speed =getprop("fdm/jsbsim/gear/unit["~me.count~"]/wheel-speed-fps") or 0;
                speed=speed*18.288;
            }
        var wow = getprop("gear/gear["~me.count~"]/wow");
        if(wow){
            me.rpm[me.count] = speed / me.circumference[me.count];
        }else{
            if(me.rpm[me.count] > 0) me.rpm[me.count]=me.rpm[me.count]*0.95;
        }
        me.tire[me.count].setValue(me.rpm[me.count]);
        me.count+=1;
        if(me.count>=me.num)me.count=0;
    },
};


#Jet Engine Helper class 
# ie: var Eng = JetEngine.new(engine number);

var JetEngine = {
    new : func(eng_num){
        m = { parents : [JetEngine]};
        m.fdensity = getprop("consumables/fuel/tank/density-ppg") or 6.72;
        m.eng = props.globals.getNode("engines/engine["~eng_num~"]",1);
        m.running = m.eng.initNode("running",0,"BOOL");
        m.n1 = m.eng.getNode("n1",1);
        m.n2 = m.eng.getNode("n2",1);
        m.fan = m.eng.initNode("fan",0,"DOUBLE");
        m.cycle_up = 0;
        m.engine_off=1;
        m.turbine = m.eng.initNode("turbine",0,"DOUBLE");
        m.throttle_lever = props.globals.initNode("controls/engines/engine["~eng_num~"]/throttle-lever",0,"DOUBLE");
        m.throttle = props.globals.initNode("controls/engines/engine["~eng_num~"]/throttle",0,"DOUBLE");
        m.ignition = props.globals.initNode("controls/engines/engine["~eng_num~"]/ignition",0,"DOUBLE");
        m.cutoff = props.globals.initNode("controls/engines/engine["~eng_num~"]/cutoffnt",1,"BOOL");
        m.fuel_out = props.globals.initNode("engines/engine["~eng_num~"]/out-of-fuel",0,"BOOL");
        m.starter = props.globals.initNode("controls/engines/engine["~eng_num~"]/starter",0,"BOOL");
        m.fuel_pph=m.eng.initNode("fuel-flow_pph",0,"DOUBLE");
        m.fuel_gph=m.eng.initNode("fuel-flow-gph");

        m.Lfuel = setlistener(m.fuel_out, func m.shutdown(m.fuel_out.getValue()),0,0);
        m.CutOff = setlistener(m.cutoff, func (ct){m.engine_off=ct.getValue()},1,0);
    return m;
    },
#### update ####
    update : func{
        var thr = me.throttle.getValue();
        if(!me.engine_off){
            me.fan.setValue(me.n1.getValue());
            me.turbine.setValue(me.n2.getValue());
            if(getprop("controls/engines/grnd_idle"))thr *=0.92;
            me.throttle_lever.setValue(thr);
        }else{
            me.throttle_lever.setValue(0);
            if(me.starter.getBoolValue()){
                if(me.cycle_up == 0)me.cycle_up=1;
            }
            if(me.cycle_up>0){
                me.spool_up(15);
            }else{
                var tmprpm = me.fan.getValue();
                if(tmprpm > 0.0){
                    tmprpm -= getprop("sim/time/delta-sec") * 2;
                    me.fan.setValue(tmprpm);
                    me.turbine.setValue(tmprpm);
                }
            }
        }
        
        me.fuel_pph.setValue(me.fuel_gph.getValue()*me.fdensity);
    },

    spool_up : func(scnds){
        if(me.engine_off){
        var n1=me.n1.getValue() ;
        var n1factor = n1/scnds;
        var n2=me.n2.getValue() ;
        var n2factor = n2/scnds;
        var tmprpm = me.fan.getValue();
            tmprpm += getprop("sim/time/delta-sec") * n1factor;
            var tmprpm2 = me.turbine.getValue();
            tmprpm2 += getprop("sim/time/delta-sec") * n2factor;
            me.fan.setValue(tmprpm);
            me.turbine.setValue(tmprpm2);
            if(tmprpm >= me.n1.getValue()){
                var ign=1-me.ignition.getValue();
                me.cutoff.setBoolValue(ign);
                me.cycle_up=0;
            }
        }
    },

    shutdown : func(b){
        if(b!=0){
            me.cutoff.setBoolValue(1);
        }
    }

};

var FDM="";
var Grd_Idle=props.globals.initNode("controls/engines/grnd-idle",1,"BOOL");

# SurferTim added
var Park_Set=props.globals.initNode("controls/gear/park-set","PARKING BRAKE","STRING");
var Land_Light=props.globals.initNode("controls/lighting/landlight","","STRING");
var Gear_Set=props.globals.initNode("controls/gear/gear-downnt",1,"BOOL");
var Flap_Set=props.globals.initNode("controls/flight/flapsnt",0.0,"DOUBLE");
props.globals.initNode("instrumentation/nav[0]/dme","---","STRING");
props.globals.initNode("instrumentation/nav[1]/dme","---","STRING");
props.globals.initNode("instrumentation/attitude-indicator/corrected-pitch-offset",0.0,"DOUBLE");
props.globals.initNode("instrumentation/attitude-indicator/corrected-roll-offset",0.0,"DOUBLE");
props.globals.initNode("instrumentation/attitude-indicator/corrected-pitch-deg",0.0,"DOUBLE");
props.globals.initNode("instrumentation/attitude-indicator/corrected-roll-deg",0.0,"DOUBLE");
props.globals.initNode("autopilot/internal/pitch-filter-gain",1.0,"DOUBLE");
props.globals.initNode("autopilot/internal/pitch-filter-start",0.0,"DOUBLE");
props.globals.initNode("engines/engine[0]/itt-c",0.0,"DOUBLE");
props.globals.initNode("engines/engine[1]/itt-c",0.0,"DOUBLE");

var Annun = props.globals.getNode("instrumentation/annunciators",1);
var MstrWarn =Annun.getNode("master-warning",1);
var MstrCaution = Annun.getNode("master-caution",1);
var PWR2 =0;
aircraft.livery.init("Aircraft/CitationX/Models/Liveries");
aircraft.light.new("instrumentation/annunciators", [0.5, 0.5], MstrCaution);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10,1);
var LHeng= JetEngine.new(0);
var RHeng= JetEngine.new(1);
var tire=TireSpeed.new(3,0.430,0.615,0.615);

#######################################

var fdm_init = func(){
    MstrWarn.setBoolValue(0);
    MstrCaution.setBoolValue(0);
    FDM=getprop("/sim/flight-model");
    setprop("controls/engines/N1-limit",95.0);
}

setlistener("/sim/signals/fdm-initialized", func {
    fdm_init();
    settimer(update_systems,2);
    settimer(fauxlistener,2);
});

setlistener("/sim/signals/reinit", func {
    fdm_init();
},0,0);

setlistener("/sim/crashed", func(cr){
    if(cr.getBoolValue()){
    }
},1,0);

setlistener("sim/model/autostart", func(strt){
    if(strt.getBoolValue()){
        Startup();
    }else{
        Shutdown();
    }
},0,0);


setlistener("/gear/gear[1]/wow", func(ww){
    if(ww.getBoolValue()){
        FHmeter.stop();
        Grd_Idle.setBoolValue(1);
    }else{
        FHmeter.start();
        Grd_Idle.setBoolValue(0);
    }
},0,0);


#setlistener("/controls/gear/antiskid", func(as){
#    var test=as.getBoolValue();
#    if(!test){
#    MstrCaution.setBoolValue(1 * PWR2);
#    Annun.getNode("antiskid").setBoolValue(1 * PWR2);
#    }else{
#    Annun.getNode("antiskid").setBoolValue(0);
#    }
#},0,0);



setlistener("/sim/freeze/fuel", func(ffr){
    var test=ffr.getBoolValue();
    if(test){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("fuel-gauge").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("fuel-gauge").setBoolValue(0);
    }
},0,0);

### Flaps ###
setlistener("controls/flight/flaps", func(n) {
  if (n.getValue() == 0) setprop(flaps_select,0);
  if (n.getValue() > 0.0427 and n.getValue() < 0.0429) setprop(flaps_select,1);
  if (n.getValue() > 0.141 and n.getValue() < 0.143) setprop(flaps_select,2);
  if (n.getValue() > 0.427 and n.getValue() <0.429) setprop(flaps_select,3);
  if (n.getValue() == 1) setprop(flaps_select,4);
},0,0);

controls.gearDown = func(v) {
    if (v < 0) {
        if(!getprop("gear/gear[1]/wow"))setprop("/controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("/controls/gear/gear-down", 1);
    }
}

controls.toggleLandingLights = func()
{
    var state = getprop("controls/lighting/landing-light");
    setprop("controls/lighting/landing-light",!state);
    setprop("controls/lighting/landing-light[1]",!state);
    var msg = "off";
    if(!state) msg = "on";
#    if(!getprop("sim/rendering/rembrandt/enabled")) msg = "not available";
}

controls.stepSpoilers = func(d)
{
	if(d == 1) setprop("controls/flight/speedbrake",1);
	if(d == -1) setprop("controls/flight/speedbrake",0);;
}

controls.ptt = func(p)
{
	if(p == 1) setprop("instrumentation/comm/ptt",1);
	else setprop("instrumentation/comm/ptt",0);;
}

var Startup = func{
    setprop("controls/electric/engine[0]/generator",1);
    setprop("controls/electric/engine[1]/generator",1);
    setprop("controls/electric/avionics-switch",1);
    setprop("controls/electric/battery-switch",1);
    setprop("controls/electric/battery-switch[1]",1);
    setprop("controls/electric/inverter-switch",1);
    setprop("controls/lighting/instrument-lights",1);
    setprop("controls/lighting/nav-lights",1);
    setprop("controls/lighting/beacon",1);
    setprop("controls/lighting/strobe",1);
    setprop("controls/engines/engine[0]/cutoff",0);
    setprop("controls/engines/engine[1]/cutoff",0);
    setprop("controls/engines/engine[0]/ignition",1);
    setprop("controls/engines/engine[1]/ignition",1);
    setprop("engines/engine[0]/running",1);
    setprop("engines/engine[1]/running",1);
    setprop("controls/engines/throttle_idle",1);
}

var Shutdown = func{
    setprop("controls/electric/engine[0]/generator",0);
    setprop("controls/electric/engine[1]/generator",0);
    setprop("controls/electric/avionics-switch",0);
    setprop("controls/electric/battery-switch",0);
    setprop("controls/electric/battery-switch[1]",0);
    setprop("controls/electric/inverter-switch",0);
    setprop("controls/lighting/instrument-lights",1);
    setprop("controls/lighting/nav-lights",0);
    setprop("controls/lighting/beacon",0);
    setprop("controls/lighting/strobe",0);
    setprop("controls/engines/engine[0]/cutoff",1);
    setprop("controls/engines/engine[1]/cutoff",1);
    setprop("controls/engines/engine[0]/ignition",0);
    setprop("controls/engines/engine[1]/ignition",0);
    setprop("engines/engine[0]/running",0);
    setprop("engines/engine[1]/running",0);
}

var FHupdate = func(tenths){
        var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
        var fhour = fmeter/3600;
        setprop("instrumentation/clock/flight-meter-hour",fhour);
        var fmin = fhour - int(fhour);
        if(tenths !=0){
            fmin *=100;
        }else{
            fmin *=60;
        }
        setprop("instrumentation/clock/flight-meter-min",int(fmin));
    }

var stall_horn = func{
    var alert=0;
    var kias=getprop("velocities/airspeed-kt");
    if(kias>150){setprop("sim/sound/stall-horn",alert);return;};
    var wow1=getprop("gear/gear[1]/wow");
    var wow2=getprop("gear/gear[2]/wow");
    if(!wow1 or !wow2){
        var grdn=getprop("controls/gear/gear-down");
        var flap=getprop("controls/flight/flaps");
        if(kias<100){
            alert=1;
        }elsif(kias<120){
            if(!grdn )alert=1;
        }else{
            if(flap==0)alert=1;
        }
    }
    setprop("sim/sound/stall-horn",alert);
}

# SurferTim added
var fauxlistener = func{
    bp = getprop("/controls/gear/brake-parking");

    if(bp){
	setprop("/controls/gear/park-set","PARKING BRAKE");
    }else{
	setprop("/controls/gear/park-set","");
    }

    setprop("controls/engines/engine/cutoffnt", getprop("controls/engines/engine/cutoff"));
    setprop("controls/engines/engine[1]/cutoffnt", getprop("controls/engines/engine[1]/cutoff"));
    setprop("controls/gear/gear-downnt", getprop("controls/gear/gear-down"));

    setprop("instrumentation/altimeter/setting-kpa",getprop("instrumentation/altimeter/setting-inhg") * 3.386389);
    setprop("instrumentation/altimeter/setting-hpant",getprop("instrumentation/altimeter/setting-hpa"));

    var altmeters = getprop("position/altitude-agl-ft") / 3.3;
    altmeters = math.pow(altmeters,2);

    if(getprop("instrumentation/primus2000/sc840/nav1ptr") == 1) {
       if(getprop("instrumentation/nav[0]/in-range")) {
          var dme1 = getprop("instrumentation/nav[0]/nav-distance") or 0.0;
          dme1 = math.pow(dme1,2);
          if(dme1 > altmeters) {
              var dmedist1 = math.sqrt(dme1 - altmeters);
          } else {
              var dmedist1 = 0.0;
          }
          dmedist1 = dmedist1 / 1852.0;
          var dme1buf = sprintf("%3.1f",dmedist1);
       } else {
          var dme1buf = "---";
       }
    } else {
       var dme1buf = "   ";
    }

    if(getprop("instrumentation/primus2000/sc840/nav2ptr") == 1) {
       if(getprop("instrumentation/nav[1]/in-range")) {
          var dme2 = getprop("instrumentation/nav[1]/nav-distance") or 0.0;
          dme2 = math.pow(dme2,2);
          if(dme2 > altmeters) {
              var dmedist2 = math.sqrt(dme2 - altmeters);
          } else {
              var dmedist2 = 0.0;
          }
          dmedist2 = dmedist2 / 1852.0;
          var dme2buf = sprintf("%3.1f",dmedist2);

       } else {
          var dme2buf = "---";
       }
    } else {
       var dme2buf = "   ";
    }

    setprop("instrumentation/nav[0]/dme",dme1buf);
    setprop("instrumentation/nav[1]/dme",dme2buf);

    if(getprop("instrumentation/attitude-indicator/caged-flag")) {
        var pitchoffset = getprop("instrumentation/attitude-indicator/indicated-pitch-deg");
        var rolloffset = getprop("instrumentation/attitude-indicator/indicated-roll-deg");
        setprop("instrumentation/attitude-indicator/corrected-pitch-offset", pitchoffset);
        setprop("instrumentation/attitude-indicator/corrected-roll-offset", rolloffset);
    }

    if(getprop("engines/engine[0]/n1") > 10.0) {
        var itt = getprop("engines/engine[0]/itt-norm") * 0.695;
        var n1 = getprop("engines/engine[0]/n1") * 0.003;

        setprop("engines/engine[0]/itt-c", itt + n1);
    }  else {
        setprop("engines/engine[0]/itt-c", 0.0);
    }

    if(getprop("engines/engine[1]/n1") > 10.0) {
        var itt = getprop("engines/engine[1]/itt-norm") * 0.695;
        var n1 = getprop("engines/engine[1]/n1") * 0.003;

        setprop("engines/engine[1]/itt-c", itt + n1);
    }  else {
        setprop("engines/engine[1]/itt-c", 0.0);
    }
    
    settimer(fauxlistener,0.2);
}

var update_gyro = func{
        var pitchdeg = getprop("instrumentation/attitude-indicator/indicated-pitch-deg");
        var rolldeg = getprop("instrumentation/attitude-indicator/indicated-roll-deg");
        var pitchoffset = getprop("instrumentation/attitude-indicator/corrected-pitch-offset");
        var rolloffset = getprop("instrumentation/attitude-indicator/corrected-roll-offset");
        setprop("instrumentation/attitude-indicator/corrected-pitch-deg", pitchdeg - pitchoffset);
        setprop("instrumentation/attitude-indicator/corrected-roll-deg", rolldeg - rolloffset);
}

########## MAIN ##############

var message_inhibited_node = props.globals.getNode ("limits/message-inhibited");
var indicated_alt_node = props.globals.getNode ("instrumentation/altimeter/indicated-altitude-ft");
var vne_node = props.globals.getNode ("limits/vne");

var update_systems = func{
    LHeng.update();
    RHeng.update();
    FHupdate(0);
    tire.get_rotation("yasim");
    stall_horn();
    if(getprop("velocities/airspeed-kt")>40)setprop("controls/cabin-door/open",0);
#annunciators_loop();
    var grspd =getprop("velocities/groundspeed-kt");
    var wspd = (45-grspd) * 0.022222;

    if(wspd>1.0)wspd=1.0;

# SurferTim changed
#    if(wspd<0.001)wspd=0.001;
    if(wspd<0.1)wspd=0.1;

    var rudder_pos=getprop("controls/flight/rudder") or 0;
    var str=-(rudder_pos*wspd);

    setprop("/controls/gear/steering",str);

    vne_node.setValue(indicated_alt_node.getValue() > 8000 ? 350 : 270);

    if (getprop ("velocities/mach") > getprop ("limits/mmo")
        and ! message_inhibited_node.getBoolValue()) {
       screen.log.write ("Mach number exceeds Mmo!");
       message_inhibited_node.setBoolValue (1);
       settimer (func () { message_inhibited_node.setBoolValue (0); }, 10);
    }

    if (getprop("systems/electrical/outputs/landing-light") > 0.1) setprop("sim/multiplay/generic/float[4]",0.9);
    else setprop("sim/multiplay/generic/float[4]",0.0);

    if (getprop("systems/electrical/outputs/landing-light[1]") > 0.1) setprop("sim/multiplay/generic/float[5]",0.9);
    else setprop("sim/multiplay/generic/float[5]",0.0);

    if (getprop("systems/electrical/outputs/taxi-lights") > 0.1) setprop("sim/multiplay/generic/float[6]",0.9);
    else setprop("sim/multiplay/generic/float[6]",0.0);

    update_gyro();


settimer(update_systems,0);
}
