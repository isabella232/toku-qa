/*
 * driver.c
 * driver for the tpcc transactions
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/times.h>
#include "tpc.h"      /* prototypes for misc. functions */
#include "trans_if.h" /* prototypes for transacation interface calls */
#include "sequence.h"
#include "rthist.h"
//#include "time.h"

// tmc : added for rate limiting
static double rate_last_seconds = 0.0;
static long rate_last_transactions = 0;
extern int num_neword_per_10_sec;
static int transaction_interval = 10;

static int other_ware (int home_ware);
static int do_neword (int t_num);
static int do_payment (int t_num);
static int do_ordstat (int t_num);
static int do_delivery (int t_num);
static int do_slev (int t_num);

extern int num_ware;
extern int num_conn;
extern int activate_transaction;
extern int counting_on;

extern int num_node;

extern int success[];
extern int late[];
extern int retry[];
extern int failure[];

extern int* success2[];
extern int* late2[];
extern int* retry2[];
extern int* failure2[];

extern float max_rt[];

extern long clk_tck;

#define MAX_RETRY 2000

#define RTIME_NEWORD   5
#define RTIME_PAYMENT  5
#define RTIME_ORDSTAT  5
#define RTIME_DELIVERY 80
#define RTIME_SLEV     20



int driver (int t_num)
{
    int i, j;

    double current_seconds = 0;
    long current_transactions = 0;
    double current_tps = 0;
    struct timeval currentTV;
    

    

    /* Actually, WaitTimes are needed... */
    while( activate_transaction ){
    
        // tmc : add rate limiting    
        if (t_num == 0)
        {
          gettimeofday(&currentTV, NULL); 
          current_seconds = currentTV.tv_sec + (currentTV.tv_usec/1000000);
          if (current_seconds > (rate_last_seconds + transaction_interval))
          { 
            rate_last_seconds = current_seconds; 
            rate_last_transactions = success[0];
          } 
        }

        // check current rate and tarpit if necessary
        gettimeofday(&currentTV, NULL); 
        current_seconds = currentTV.tv_sec + (currentTV.tv_usec/1000000);
        current_transactions = success[0];
        current_tps = ((current_transactions - rate_last_transactions) / (current_seconds - rate_last_seconds) * transaction_interval);

//            if (t_num == 1)
//            {
//              printf("thread %d : tps = %f\n",t_num,current_tps);
//              printf("thread %d : tps = %f : cur_secs = %f : last_secs = %f : cur_txn = %f : last_txn = %f\n",t_num,current_tps,current_seconds,rate_last_seconds,current_transactions,rate_last_transactions);
//            }

        while (current_tps > num_neword_per_10_sec)
        {
          usleep(100000);
          gettimeofday(&currentTV, NULL); 
          current_seconds = currentTV.tv_sec + (currentTV.tv_usec/1000000);
          current_transactions = success[0];
          current_tps = ((current_transactions - rate_last_transactions) / (current_seconds - rate_last_seconds) * transaction_interval);
        }
    
    
    
      switch(seq_get()){
      case 0:
	do_neword(t_num);
	break;
      case 1:
	do_payment(t_num);
	break;
      case 2:
	do_ordstat(t_num);
	break;
      case 3:
	do_delivery(t_num);
	break;
      case 4:
	do_slev(t_num);
	break;
      default:
	printf("Error - Unknown sequence.\n");
      }

    }

    return(0);

}

/*
 * prepare data and execute the new order transaction for one order
 * officially, this is supposed to be simulated terminal I/O
 */
static int do_neword (int t_num)
{
    int c_num;
    int i,ret;
    clock_t clk1,clk2;
    float rt;
    struct tms tbuf;
    int  w_id, d_id, c_id, ol_cnt;
    int  all_local = 1;
    int  notfound = MAXITEMS+1;  /* valid item ids are numbered consecutively
				    [1..MAXITEMS] */
    int rbk;
    int  itemid[MAX_NUM_ITEMS];
    int  supware[MAX_NUM_ITEMS];
    int  qty[MAX_NUM_ITEMS];

    if(num_node==0){
	w_id = RandomNumber(1, num_ware);
    }else{
	c_num = ((num_node * t_num)/num_conn); /* drop moduls */
	w_id = RandomNumber(1 + (num_ware * c_num)/num_node,
			    (num_ware * (c_num + 1))/num_node);
    }
    d_id = RandomNumber(1, DIST_PER_WARE);
    c_id = NURand(1023, 1, CUST_PER_DIST);

    ol_cnt = RandomNumber(5, 15);
    rbk = RandomNumber(1, 100);

    for (i = 0; i < ol_cnt; i++) {
	itemid[i] = NURand(8191, 1, MAXITEMS);
	if ((i == ol_cnt - 1) && (rbk == 1)) {
	    itemid[i] = notfound;
	}
	if (RandomNumber(1, 100) != 1) {
	    supware[i] = w_id;
	}
	else {
	    supware[i] = other_ware(w_id);
	    all_local = 0;
	}
	qty[i] = RandomNumber(1, 10);
    }

    for (i = 0; i < MAX_RETRY; i++) {
      clk1 = times( &tbuf );
      ret = neword(t_num, w_id, d_id, c_id, ol_cnt, all_local, itemid, supware, qty);
      clk2 = times( &tbuf );

      if(ret){

	rt = (float)(clk2 - clk1)/(float)clk_tck;
	if(rt > max_rt[0])
	  max_rt[0]=rt;
	hist_inc(0, clk2 - clk1);
	if(counting_on){
	  if( (clk2 - clk1) / clk_tck < RTIME_NEWORD ){
	    success[0]++;
	    success2[0][t_num]++;
	  }else{
	    late[0]++;
	    late2[0][t_num]++;
	  }
	}

	return (1); /* end */
      }else{

	if(counting_on){
	  retry[0]++;
	  retry2[0][t_num]++;
	}

      }
    }

    if(counting_on){
      retry[0]--;
      retry2[0][t_num]--;
      failure[0]++;
      failure2[0][t_num]++;
    }

    return (0);
}

/*
 * produce the id of a valid warehouse other than home_ware
 * (assuming there is one)
 */
static int other_ware (int home_ware)
{
    int tmp;

    if (num_ware == 1) return home_ware;
    while ((tmp = RandomNumber(1, num_ware)) == home_ware);
    return tmp;
}

/*
 * prepare data and execute payment transaction
 */
static int do_payment (int t_num)
{
    int c_num;
    int byname,i,ret;
    clock_t clk1,clk2;
    float rt;
    struct tms tbuf;
    int  w_id, d_id, c_w_id, c_d_id, c_id, h_amount;
    char c_last[17];

    if(num_node==0){
	w_id = RandomNumber(1, num_ware);
    }else{
	c_num = ((num_node * t_num)/num_conn); /* drop moduls */
	w_id = RandomNumber(1 + (num_ware * c_num)/num_node,
			    (num_ware * (c_num + 1))/num_node);
    }
    d_id = RandomNumber(1, DIST_PER_WARE);
    c_id = NURand(1023, 1, CUST_PER_DIST); 
    Lastname(NURand(255,0,999), c_last); 
    h_amount = RandomNumber(1,5000);
    if (RandomNumber(1, 100) <= 60) {
        byname = 1; /* select by last name */
    }else{
        byname = 0; /* select by customer id */
    }
    if (RandomNumber(1, 100) <= 85) {
        c_w_id = w_id;
        c_d_id = d_id;
    }else{
        c_w_id = other_ware(w_id);
        c_d_id = RandomNumber(1, DIST_PER_WARE);
    }

    for (i = 0; i < MAX_RETRY; i++) {
      clk1 = times( &tbuf );
      ret = payment(t_num, w_id, d_id, byname, c_w_id, c_d_id, c_id, c_last, h_amount);
      clk2 = times( &tbuf );

      if(ret){

	rt = (float)(clk2 - clk1)/(float)clk_tck;
	if(rt > max_rt[1])
	  max_rt[1]=rt;
	hist_inc(1, clk2 - clk1);
	if(counting_on){
	  if( (clk2 - clk1) / clk_tck < RTIME_PAYMENT ){
	    success[1]++;
	    success2[1][t_num]++;
	  }else{
	    late[1]++;
	    late2[1][t_num]++;
	  }
	}

	return (1); /* end */
      }else{

	if(counting_on){
	  retry[1]++;
	  retry2[1][t_num]++;
	}

      }
    }

    if(counting_on){
      retry[1]--;
      retry2[1][t_num]--;
      failure[1]++;
      failure2[1][t_num]++;
    }

    return (0);
}

/*
 * prepare data and execute order status transaction
 */
static int do_ordstat (int t_num)
{
    int c_num;
    int byname,i,ret;
    clock_t clk1,clk2;
    float rt;
    struct tms tbuf;
    int  w_id, d_id, c_id;
    char c_last[16];

    if(num_node==0){
	w_id = RandomNumber(1, num_ware);
    }else{
	c_num = ((num_node * t_num)/num_conn); /* drop moduls */
	w_id = RandomNumber(1 + (num_ware * c_num)/num_node,
			    (num_ware * (c_num + 1))/num_node);
    }
    d_id = RandomNumber(1, DIST_PER_WARE);
    c_id = NURand(1023, 1, CUST_PER_DIST); 
    Lastname(NURand(255,0,999), c_last); 
    if (RandomNumber(1, 100) <= 60) {
        byname = 1; /* select by last name */
    }else{
        byname = 0; /* select by customer id */
    }

    for (i = 0; i < MAX_RETRY; i++) {
      clk1 = times( &tbuf );
      ret = ordstat(t_num, w_id, d_id, byname, c_id, c_last);
      clk2 = times( &tbuf );

      if(ret){

	rt = (float)(clk2 - clk1)/(float)clk_tck;
	if(rt > max_rt[2])
	  max_rt[2]=rt;
	hist_inc(2, clk2 - clk1);
	if(counting_on){
	  if( (clk2 - clk1) / clk_tck < RTIME_ORDSTAT ){
	    success[2]++;
	    success2[2][t_num]++;
	  }else{
	    late[2]++;
	    late2[2][t_num]++;
	  }
	}

	return (1); /* end */
      }else{

	if(counting_on){
	  retry[2]++;
	  retry2[2][t_num]++;
	}

      }
    }

    if(counting_on){
      retry[2]--;
      retry2[2][t_num]--;
      failure[2]++;
      failure2[2][t_num]++;
    }

    return (0);

}

/*
 * execute delivery transaction
 */
static int do_delivery (int t_num)
{
    int c_num;
    int i,ret;
    clock_t clk1,clk2;
    float rt;
    struct tms tbuf;
    int  w_id, o_carrier_id;

    if(num_node==0){
	w_id = RandomNumber(1, num_ware);
    }else{
	c_num = ((num_node * t_num)/num_conn); /* drop moduls */
	w_id = RandomNumber(1 + (num_ware * c_num)/num_node,
			    (num_ware * (c_num + 1))/num_node);
    }
    o_carrier_id = RandomNumber(1, 10);

    for (i = 0; i < MAX_RETRY; i++) {
      clk1 = times( &tbuf );
      ret = delivery(t_num, w_id, o_carrier_id);
      clk2 = times( &tbuf );

      if(ret){

	rt = (float)(clk2 - clk1)/(float)clk_tck;
	if(rt > max_rt[3])
	  max_rt[3]=rt;
	hist_inc(3, clk2 - clk1);
	if(counting_on){
	  if( (clk2 - clk1) / clk_tck < RTIME_DELIVERY ){
	    success[3]++;
	    success2[3][t_num]++;
	  }else{
	    late[3]++;
	    late2[3][t_num]++;
	  }
	}

	return (1); /* end */
      }else{

	if(counting_on){
	  retry[3]++;
	  retry2[3][t_num]++;
	}

      }
    }

    if(counting_on){
      retry[3]--;
      retry2[3][t_num]--;
      failure[3]++;
      failure2[3][t_num]++;
    }

    return (0);

}

/* 
 * prepare data and execute the stock level transaction
 */
static int do_slev (int t_num)
{
    int c_num;
    int i,ret;
    clock_t clk1,clk2;
    float rt;
    struct tms tbuf;
    int  w_id, d_id, level;

    if(num_node==0){
	w_id = RandomNumber(1, num_ware);
    }else{
	c_num = ((num_node * t_num)/num_conn); /* drop moduls */
	w_id = RandomNumber(1 + (num_ware * c_num)/num_node,
			    (num_ware * (c_num + 1))/num_node);
    }
    d_id = RandomNumber(1, DIST_PER_WARE); 
    level = RandomNumber(10, 20); 

    for (i = 0; i < MAX_RETRY; i++) {
      clk1 = times( &tbuf );
      ret = slev(t_num, w_id, d_id, level);
      clk2 = times( &tbuf );

      if(ret){

	rt = (float)(clk2 - clk1)/(float)clk_tck;
	if(rt > max_rt[4])
	  max_rt[4]=rt;
	hist_inc(4, clk2 - clk1);
	if(counting_on){
	  if( (clk2 - clk1) / clk_tck < RTIME_SLEV ){
	    success[4]++;
	    success2[4][t_num]++;
	  }else{
	    late[4]++;
	    late2[4][t_num]++;
	  }
	}

	return (1); /* end */
      }else{

	if(counting_on){
	  retry[4]++;
	  retry2[4][t_num]++;
	}

      }
    }

    if(counting_on){
      retry[4]--;
      retry2[4][t_num]--;
      failure[4]++;
      failure2[4][t_num]++;
    }

    return (0);

}
