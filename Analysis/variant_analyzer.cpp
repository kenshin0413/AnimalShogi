#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <random>
#include <string>
#include <unordered_map>
#include <vector>
using namespace std;

enum Type { EMPTY, LION, GIRAFFE, ELEPHANT, CHICK, HEN };
struct Move { int from, to, drop; };
struct Rules { int rows=4, cols=3; bool promotion=true; int chicks=1; array<int,3> back={GIRAFFE,LION,ELEPHANT}; int chickColumn=1; };
struct State {
    Rules r; array<int8_t,20> b{}; int hand[2][6]{}; int turn=0; int winner=-1; int ply=0;
};
static mt19937 rng(20260920);
static int repetitionLimit=3;
static bool repetitionMoverLoses=false;
static bool allowLastRankChickDrop=false;

int owner(int p){ return p>0?0:(p<0?1:-1); }
int typeOf(int p){ return abs(p); }
int piece(int owner, int type){ return owner==0?type:-type; }
int goal(const State&s,int p){ return p==0?0:s.r.rows-1; }
int forward(int p){ return p==0?-1:1; }

State initial(const Rules&r){
    State s; s.r=r;
    for(int c=0;c<r.cols;c++){
        s.b[c]=piece(1,r.back[c]);
        s.b[(r.rows-1)*r.cols+c]=piece(0,r.back[r.cols-1-c]);
    }
    if(r.chicks==1){
        s.b[r.cols+r.chickColumn]=piece(1,CHICK);
        s.b[(r.rows-2)*r.cols+(r.cols-1-r.chickColumn)]=piece(0,CHICK);
    } else {
        s.b[r.cols]=piece(1,CHICK); s.b[r.cols+2]=piece(1,CHICK);
        s.b[(r.rows-2)*r.cols]=piece(0,CHICK); s.b[(r.rows-2)*r.cols+2]=piece(0,CHICK);
    }
    return s;
}

vector<pair<int,int>> offsets(int type,int p){
    int f=forward(p);
    if(type==LION) return {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}};
    if(type==GIRAFFE) return {{0,-1},{-1,0},{1,0},{0,1}};
    if(type==ELEPHANT) return {{-1,-1},{1,-1},{-1,1},{1,1}};
    if(type==CHICK) return {{0,f}};
    return {{-1,f},{0,f},{1,f},{-1,0},{1,0},{0,-f}};
}

bool attacked(const State&s,int square,int by){
    int tr=square/s.r.cols, tc=square%s.r.cols;
    for(int i=0;i<s.r.rows*s.r.cols;i++) if(s.b[i] && owner(s.b[i])==by){
        int rr=i/s.r.cols, cc=i%s.r.cols;
        for(auto [dx,dy]:offsets(typeOf(s.b[i]),by)) if(rr+dy==tr && cc+dx==tc) return true;
    }
    return false;
}

State rawApply(State s,const Move&m,bool terminal=true){
    int p=s.turn, moving;
    if(m.drop){ moving=piece(p,m.drop); s.hand[p][m.drop]--; }
    else { moving=s.b[m.from]; s.b[m.from]=0; }
    int cap=s.b[m.to];
    if(cap && typeOf(cap)!=LION) s.hand[p][typeOf(cap)==HEN?CHICK:typeOf(cap)]++;
    int t=typeOf(moving);
    if(!m.drop && t==CHICK && s.r.promotion && m.to/s.r.cols==goal(s,p)) moving=piece(p,HEN);
    s.b[m.to]=moving; s.ply++;
    if(terminal && cap && typeOf(cap)==LION){ s.winner=p; s.turn=1-p; return s; }
    if(terminal && typeOf(moving)==LION && m.to/s.r.cols==goal(s,p)){ s.winner=p; s.turn=1-p; return s; }
    s.turn=1-p; return s;
}

vector<Move> moves(const State&s){
    if(s.winner>=0) return {};
    vector<Move> out; int p=s.turn, n=s.r.rows*s.r.cols;
    auto safe=[&](Move m){
        State q=rawApply(s,m,false); int lion=-1;
        for(int i=0;i<n;i++) if(q.b[i] && owner(q.b[i])==p && typeOf(q.b[i])==LION) lion=i;
        return lion>=0 && !attacked(q,lion,1-p);
    };
    for(int i=0;i<n;i++) if(s.b[i] && owner(s.b[i])==p){
        int rr=i/s.r.cols, cc=i%s.r.cols;
        for(auto [dx,dy]:offsets(typeOf(s.b[i]),p)){
            int r=rr+dy,c=cc+dx; if(r<0||r>=s.r.rows||c<0||c>=s.r.cols) continue;
            int to=r*s.r.cols+c; if(s.b[to] && owner(s.b[to])==p) continue;
            Move m{i,to,0}; if(safe(m)) out.push_back(m);
        }
    }
    for(int t=GIRAFFE;t<=CHICK;t++) if(s.hand[p][t]) for(int to=0;to<n;to++) if(!s.b[to]){
        if(!allowLastRankChickDrop && t==CHICK && to/s.r.cols==goal(s,p)) continue;
        Move m{-1,to,t}; if(safe(m)) out.push_back(m);
    }
    return out;
}

uint64_t hashState(const State&s){
    uint64_t h=1469598103934665603ULL;
    for(int i=0;i<s.r.rows*s.r.cols;i++){ h^=(uint8_t)(s.b[i]+6); h*=1099511628211ULL; }
    for(int p=0;p<2;p++) for(int t=2;t<=4;t++){ h^=(uint8_t)s.hand[p][t]; h*=1099511628211ULL; }
    h^=s.turn; return h*1099511628211ULL;
}

int valueOf(int t){ static int v[]={0,10000,330,300,110,520}; return v[t]; }
int evaluate(const State&s){
    if(s.winner>=0) return s.winner==s.turn?100000-s.ply:-100000+s.ply;
    int score=0,n=s.r.rows*s.r.cols;
    for(int i=0;i<n;i++) if(s.b[i]){
        int p=owner(s.b[i]),t=typeOf(s.b[i]), sign=p==s.turn?1:-1;
        score+=sign*valueOf(t);
        if(t==LION){ int progress=s.r.rows-1-abs(goal(s,p)-i/s.r.cols); score+=sign*progress*18; }
    }
    for(int p=0;p<2;p++) for(int t=2;t<=4;t++) score+=(p==s.turn?1:-1)*s.hand[p][t]*valueOf(t)*11/10;
    return score;
}

int negamax(const State&s,int depth,int alpha,int beta,unordered_map<uint64_t,pair<int,int>>&tt){
    if(s.winner>=0||depth==0) return evaluate(s);
    uint64_t h=hashState(s)^(uint64_t(depth)<<56);
    auto it=tt.find(h); if(it!=tt.end()&&it->second.first>=depth) return it->second.second;
    auto ms=moves(s); if(ms.empty()) return -90000+s.ply;
    int best=-1000000;
    sort(ms.begin(),ms.end(),[&](auto&a,auto&b){return typeOf(s.b[a.to])>typeOf(s.b[b.to]);});
    for(auto&m:ms){ int v=-negamax(rawApply(s,m),depth-1,-beta,-alpha,tt); best=max(best,v); alpha=max(alpha,v); if(alpha>=beta)break; }
    tt[h]={depth,best}; return best;
}

vector<pair<int,Move>> ranked(const State&s,int depth){
    unordered_map<uint64_t,pair<int,int>> tt; vector<pair<int,Move>> a;
    for(auto&m:moves(s)) a.push_back({-negamax(rawApply(s,m),depth-1,-1000000,1000000,tt),m});
    sort(a.begin(),a.end(),[](auto&a,auto&b){return a.first>b.first;}); return a;
}

int play(const Rules&r,int depth,double noise,int &outPly,int maxPly=180){
    State s=initial(r); unordered_map<uint64_t,int> seen; seen[hashState(s)]=1;
    while(s.winner<0&&s.ply<maxPly){
        auto a=ranked(s,depth); if(a.empty()){ outPly=s.ply; return 1-s.turn; }
        int pick=0;
        uniform_real_distribution<double> u(0,1);
        if(a.size()>1 && u(rng)<noise){ int near=1; while(near<(int)a.size()&&a[0].first-a[near].first<180)near++; uniform_int_distribution<int>d(0,near-1);pick=d(rng); }
        s=rawApply(s,a[pick].second);
        if(++seen[hashState(s)]>=repetitionLimit){ outPly=s.ply; return repetitionMoverLoses?s.turn:2; }
    }
    outPly=s.ply; return s.winner>=0?s.winner:2;
}

void benchmark(string name,const Rules&r,int games,int depth,double noise){
    int w[3]={}; long long plies=0;
    for(int i=0;i<games;i++){ int p=0,x=play(r,depth,noise,p);w[x]++;plies+=p; }
    State root=initial(r); auto a=ranked(root,depth+2);
    cout<<name<<",S="<<w[0]<<",G="<<w[1]<<",D="<<w[2]<<",Srate="<<(100.0*w[0]/games)
        <<",score="<<(100.0*(w[0]+w[2]*0.5)/games)<<",avgPly="<<(1.0*plies/games)
        <<",root="<<(a.empty()?0:a[0].first)<<",moves="<<moves(root).size()<<"\n";
}

int main(int argc,char**argv){
    int games=argc>1?stoi(argv[1]):120, depth=argc>2?stoi(argv[2]):5; double noise=argc>3?stod(argv[3]):0.18;
    if(argc>5) rng.seed((uint32_t)stoul(argv[5]));
    if(argc>6) repetitionLimit=stoi(argv[6]);
    if(argc>4 && (string(argv[4])=="recommended" || string(argv[4])=="recommended-loss" || string(argv[4])=="recommended-loss-drop")){
        repetitionMoverLoses=string(argv[4])!="recommended";
        allowLastRankChickDrop=string(argv[4])=="recommended-loss-drop";
        Rules q;q.rows=5;q.back={GIRAFFE,ELEPHANT,LION};q.chickColumn=2;
        benchmark("RECOMMENDED-3x5",q,games,depth,noise);
        return 0;
    }
    if(argc>4 && string(argv[4])=="layout"){
        int layoutId=stoi(argv[7]), col=stoi(argv[8]);
        array<int,3>x={LION,GIRAFFE,ELEPHANT};
        for(int i=0;i<layoutId;i++) next_permutation(x.begin(),x.end());
        Rules q;q.rows=5;q.back=x;q.chickColumn=col;
        benchmark("LAYOUT-"+to_string(layoutId)+"-C"+to_string(col),q,games,depth,noise);
        return 0;
    }
    if(argc>4 && string(argv[4])=="top"){
        Rules q;q.rows=5;
        q.back={LION,ELEPHANT,GIRAFFE};q.chickColumn=0;benchmark("TOP-L-E-G-c0",q,games,depth,noise);
        q.back={GIRAFFE,ELEPHANT,LION};q.chickColumn=2;benchmark("ALT-G-E-L-c2",q,games,depth,noise);
        q.back={GIRAFFE,LION,ELEPHANT};q.chickColumn=1;benchmark("STD-G-L-E-c1",q,games,depth,noise);
        q.back={ELEPHANT,LION,GIRAFFE};q.chickColumn=2;benchmark("DRAWISH-E-L-G-c2",q,games,depth,noise);
        return 0;
    }
    if(argc>4 && string(argv[4])=="base"){
        Rules q; benchmark("CURRENT-3x4",q,games,depth,noise);
        q.rows=5;q.back={GIRAFFE,ELEPHANT,LION};q.chickColumn=2;
        benchmark("RECOMMENDED-3x5",q,games,depth,noise);
        return 0;
    }
    Rules a; benchmark("3x4-1chick-promote",a,games,depth,noise);
    Rules b=a;b.rows=5; benchmark("3x5-1chick-promote",b,games,depth,noise);
    Rules c=b;c.chicks=2; benchmark("3x5-2chick-promote",c,games,depth,noise);
    Rules d=a;d.promotion=false;benchmark("3x4-1chick-noPromotion",d,games,depth,noise);
    Rules e=b;e.promotion=false;benchmark("3x5-1chick-noPromotion",e,games,depth,noise);
    if(argc>4){
        array<int,3>x={GIRAFFE,LION,ELEPHANT}; int id=0;
        sort(x.begin(),x.end());
        do { for(int col=0;col<3;col++){ Rules q=b;q.back=x;q.chickColumn=col; benchmark("layout-"+to_string(id)+"-c"+to_string(col),q,games,depth,noise); } id++; } while(next_permutation(x.begin(),x.end()));
    }
}
