#title "SLS Full Runtime Test"
#version 2
#debug yes

-- ============================================================
-- SLS FULL RUNTIME TEST
-- Seth handles inventory and relationship testing.
-- Producer handles relationship extremes and aliases.
-- ============================================================


-- ============================================================
-- SETH: ENTRY
-- ============================================================

::    seth_cookie

?!memory.met_seth
	@seth
	Hello.

	@seth
	This appears to be Test Hell.

	@seth
	...

	@seth
	Would you like a cookie?

	> Yes.
		+item.cookie
		+memory.took_cookie
		+memory.met_seth
		+relationship.seth+3
		->  accepted_cookie

	> No.
		+memory.refused_cookie
		+memory.met_seth
		+relationship.seth-1
		->   refused_cookie


?memory.met_seth & ?memory.took_cookie & ?!memory.cookie_resolved
	@seth
	Oh, you again!

	@seth
	Still have that cookie?

	>  Give it back.
		?item.cookie
		-item.cookie
		+memory.returned_cookie
		+memory.cookie_resolved
		+relationship.seth+8
		->   returned_cookie

	>  I ate it.
		?!item.cookie
		+memory.ate_cookie
		+memory.cookie_resolved
		+relationship.seth+2
		->   ate_cookie

	>  I'm keeping it.
		?item.cookie
		+memory.kept_cookie
		+memory.cookie_resolved
		+relationship.seth-4
		->   kept_cookie


?memory.met_seth & ?memory.refused_cookie & ?!memory.cookie_resolved
	@seth
	Changed your mind?

	>   Yes, please.
		-memory.refused_cookie
		+item.cookie
		+memory.took_cookie
		+relationship.seth+4
		->   changed_mind

	>   No, I'm fine.
		+relationship.seth-1
		->   stubborn


?memory.met_seth & ?memory.cookie_resolved
	@seth
	Did you need something?

	>  Can I have another cookie?
		?!item.cookie
		+item.cookie
		+relationship.seth-1
		->  another_cookie

	>  How many cookies do I have?
		?item.cookie
		@seth
		You currently have ^{%item.cookie}.

		@seth
		I don't know why you needed me to tell you that.

		->  cookie_count

	>  How are we doing?
		?relationship.seth
		-> seth_relationship_report

	> Nevermind.

-- ============================================================
-- SETH: COOKIE RESULTS
-- ============================================================

::     accepted_cookie

@seth
Here you go.

@seth
Have fun.

@seth
Apparently accepting baked goods is worth three friendship points now.

-> seth_relationship_report


::     refused_cookie
@seth
Okay.

@seth
Probably for the best.

@seth
I am apparently mildly offended anyway.

-> seth_relationship_report


::     changed_mind

@seth
Alright, here you go!

@seth
Have fun!

@seth
Changing your mind has apparently improved our relationship.

-> seth_relationship_report


::     stubborn

@seth
Alright, not a problem.

@seth
I will pretend this interaction never happened.

->  seth_end


::    returned_cookie

@seth
Oh, thank you!

@seth
I was beginning to think I'd never see that cookie again.

@seth
For this astonishing act of heroism, you have received an absurd relationship bonus.

->  seth_relationship_report


::    ate_cookie

@seth
Oh?

@seth
Glad you enjoyed it.

@seth
Honestly, that was the intended purpose of the cookie.

->  seth_relationship_report


::    kept_cookie

@seth
Ah, that's alright.

@seth
It's all yours.

@seth
I'm only slightly judging you.

->  seth_relationship_report


::    another_cookie

@seth
Another one?

@seth
Fine.

@seth
But I'm beginning to suspect this is becoming an inventory test.

->  seth_relationship_report


::    cookie_count

@seth
There.

@seth
Now you know.

->  seth_end


-- ============================================================
-- SETH: RELATIONSHIP REPORT
-- ============================================================

::   seth_relationship_report

@seth
According to the machine, our relationship value is ^{%relationship.seth}.

?relationship.seth >= 15
	@seth
	Apparently we're extremely close.

	@seth
	I hope you're happy.

	-> seth_end


?relationship.seth >= 10 & ?relationship.seth < 15
	@seth
	We're doing pretty well.

	@seth
	I suppose I can tolerate you voluntarily.

	-> seth_end


?relationship.seth >= 5 & ?relationship.seth < 10
	@seth
	I'd call us friends.

	@seth
	Not best friends.

	@seth
	Don't get ambitious.

	-> seth_end


?relationship.seth > -5 & ?relationship.seth < 5
	@seth
	We're somewhere around neutral.

	@seth
	Which is probably the healthiest result this test can produce.

	-> seth_end


?relationship.seth <= -5 & ?relationship.seth > -10
	@seth
	I'm beginning to dislike you.

	@seth
	Consider this an opportunity for personal growth.

	-> seth_end


?relationship.seth <= -10 & ?relationship.seth > -15
	@seth
	I'm really not fond of you.

	@seth
	At all.

	-> seth_end


?relationship.seth <= -15
	@seth
	Please leave.

	@seth
	Actually, don't even say goodbye.

	-> seth_end


::   seth_end

@seth
See you later.


-- ============================================================
-- PRODUCER: ENTRY
-- ============================================================

::   producer_start

?!memory.met_producer
	@producer
	And who are you?

	@producer
	Actually, nevermind.

	@producer
	I'll figure it out eventually.

	+memory.met_producer
	+relationship.producer

	-> producer_introduction


?memory.met_producer
	@producer
	Why are you talking to me?

	@producer
	...

	@producer
	Probably because I'm here.

	@producer
	Pretend I'm not here, okay?

	-> producer_menu


-- ============================================================
-- PRODUCER: INTRODUCTION
-- ============================================================

::   producer_introduction

@producer
I'm the Producer.

@producer
Yes, that is my name.

@producer
No, I'm not explaining it.

@producer
Apparently our relationship currently has a numerical value of ^{%relationship.producer}.

@producer
How clinical.

-> producer_menu


-- ============================================================
-- PRODUCER: MENU
-- ============================================================

::   producer_menu

@producer
Well?

> Compliment him excessively.
	+relationship.producer+17
	-> producer_massive_positive


> Insult him catastrophically.
	+relationship.producer-14
	-> producer_massive_negative


> Give him a cookie.
	?item.cookie
	-item.cookie
	+relationship.producer+6
	+memory.gave_producer_cookie
	-> producer_cookie


> Ask about your relationship.
	?relationship.producer
	-> producer_relationship_report


> Perform relationship stress tests.
	-> relationship_lab


> Goodbye.
	-> producer_end


-- ============================================================
-- PRODUCER: LARGE POSITIVE CHANGE
-- ============================================================

::   producer_massive_positive

@producer
...

@producer
That was excessive.

@producer
Our relationship is apparently ^{%relationship.producer} now.

@producer
I don't know whether I should be flattered or concerned.

> Compliment him AGAIN.
	+relationship.producer+17
	-> producer_positive_clamp

> Stop while you're ahead.
	-> producer_relationship_report


::   producer_positive_clamp

@producer
You did it again.

@producer
Wonderful.

@producer
The system claims our relationship is ^{%relationship.producer}.

@producer
If that number is above twenty, something has gone terribly wrong.

-> producer_relationship_report


-- ============================================================
-- PRODUCER: LARGE NEGATIVE CHANGE
-- ============================================================

::   producer_massive_negative

@producer
...

@producer
Excuse me?

@producer
Our relationship is apparently ^{%relationship.producer} now.

@producer
You understand I can hear you, correct?

> Insult him AGAIN.
	+relationship.producer-14
	-> producer_negative_clamp

> Apologize.
	+relationship.producer+7
	-> producer_apology

> Run away.
	-> producer_relationship_report


::   producer_negative_clamp

@producer
Remarkable.

@producer
You somehow found a second terrible thing to say.

@producer
Our relationship value is now ^{%relationship.producer}.

@producer
If it is below negative twenty, the relationship manager has failed its one job.

-> producer_relationship_report


::   producer_apology

@producer
Hm.

@producer
Fine.

@producer
That helped.

@producer
A little.

-> producer_relationship_report


-- PRODUCER: COOKIE

::   producer_cookie

@producer
Why are you giving me this?

@producer
...

@producer
Fine.

@producer
I appreciate the gesture.

@producer
Do not interpret that as enthusiasm.

@producer
Apparently that was worth six relationship points.

->  producer_relationship_report


-- PRODUCER: RELATIONSHIP REPORT

::    producer_relationship_report

@producer
Current relationship value: ^{%relationship.producer}.

?relationship.producer = 20
	@producer
	Twenty.

	@producer
	Maximum.

	@producer
	I suppose we're inseparable now.

	@producer
	Please don't tell anyone I said that.

	->  producer_end


?relationship.producer >= 15 & ?relationship.producer < 20
	@producer
	That is alarmingly positive.

	@producer
	We're apparently very close.

	@producer
	I'm going to blame the test environment.

	->  producer_end


?relationship.producer >= 10 & ?relationship.producer < 15
	@producer
	You're alright.

	@producer
	Do not make me repeat that.

	->  producer_end


?relationship.producer >= 5 & ?relationship.producer < 10
	@producer
	I suppose I like you.

	@producer
	A perfectly ordinary amount.

	->  producer_end


?relationship.producer > -5 & ?relationship.producer < 5
	@producer
	Neutral.

	@producer
	Delightfully uneventful.

	->  producer_end


?relationship.producer <= -5 & ?relationship.producer > -10
	@producer
	You're beginning to irritate me.

	@producer
	I recommend reversing course.

	->  producer_end


?relationship.producer <= -10 & ?relationship.producer > -15
	@producer
	I actively dislike you.

	@producer
	Congratulations.

	->  producer_end


?relationship.producer <= -15 & ?relationship.producer > -20
	@producer
	You are dangerously close to exhausting what little patience I have.

	->  producer_end


?relationship.producer = -20
	@producer
	Negative twenty.

	@producer
	Absolute minimum.

	@producer
	I'm impressed.

	@producer
	Not positively.

	->  producer_end


-- RELATIONSHIP LAB

::    relationship_lab

@producer
Oh, wonderful.

@producer
A laboratory dedicated entirely to manipulating how much I tolerate you.

@producer
	This is healthy.

> Set relationship to exactly zero.
	+relationship.producer=0
	->  relationship_zero


> Set relationship to exactly ten.
	+relationship.producer=10
	->  relationship_ten


> Set relationship to exactly negative ten.
	+relationship.producer=-10
	->  relationship_negative_ten


> Attempt to set relationship to ninety-nine.
	+relationship.producer=99
	->  relationship_overflow_positive


> Attempt to set relationship to negative ninety-nine.
	+relationship.producer=-99
	->  relationship_overflow_negative


> Clear the relationship entirely.
	-relationship.producer
	->  relationship_cleared


> Nevermind.
	->  producer_end


-- EXACT SET TESTS

:: relationship_zero

@producer
You set it to ^{%relationship.producer}.

?relationship.producer = 0
	@producer
	Perfect neutrality.

	@producer
	We've successfully become acquaintances in a waiting room.

	-> relationship_lab


:: relationship_ten

@producer
Current value: ^{%relationship.producer}.

?relationship.producer = 10
	@producer
	Exactly ten.

	@producer
	How suspiciously precise.

	-> relationship_lab


:: relationship_negative_ten

@producer
Current value: ^{%relationship.producer}.

?relationship.producer = -10
	@producer
	Exactly negative ten.

	@producer
	I dislike you with mathematical precision.

	-> relationship_lab


-- CLAMP TESTS

:: relationship_overflow_positive

@producer
You attempted to set the relationship to ninety-nine.

@producer
The actual stored value is ^{%relationship.producer}.

?relationship.producer = 20
	@producer
	Good.

	@producer
	The upper clamp works.

	@producer
	I remain incapable of liking you more than the system permits.

	-> relationship_lab


:: relationship_overflow_negative

@producer
You attempted to set the relationship to negative ninety-nine.

@producer
The actual stored value is ^{%relationship.producer}.

?relationship.producer = -20
	@producer
	Excellent.

	@producer
	The lower clamp works.

	@producer
	I am now as angry as mathematics permits.

	->  relationship_lab


-- CLEAR / EXISTENCE TEST

:: relationship_cleared

@producer
You just deleted our relationship.

?!relationship.producer
	@producer
	And the existence Check correctly reports that it is gone.

	@producer
	That's mildly existential.

	> Recreate it neutrally.
		+relationship.producer
		->  relationship_recreated

	> Recreate it positively.
		+relationship.producer+7
		->  relationship_recreated

	> Recreate it negatively.
		+relationship.producer-7
		->  relationship_recreated


:: relationship_recreated

@producer
And now it exists again.

@producer
Current value: ^{%relationship.producer}.

?relationship.producer
	@producer
	The existence Check agrees.

	->  relationship_lab


-- CROSS-CHARACTER RELATIONSHIP TEST

:: cross_relationship_test

@producer
Let's manipulate someone who isn't even in the room.

@producer
Poor ^{@nate}.

+relationship.nate=0

@producer
Nate begins at ^{%relationship.nate}.

+relationship.nate+19

@producer
Now ^{@nate} is at ^{%relationship.nate}.

+relationship.nate+19

@producer
And after another absurd increase, ^{@nate} is at ^{%relationship.nate}.

?relationship.nate = 20
	@producer
	Upper clamp confirmed.

+relationship.nate-40

@producer
Now we've subtracted forty.

@producer
Nate is at ^{%relationship.nate}.

?relationship.nate = -20
	@producer
	Lower clamp confirmed.

+relationship.nate=0

@producer
I've returned ^{@nate} to neutral.

@producer
He will never know what happened here.

->  producer_end


-- COMPOUND RELATIONSHIP CHECKS

:: compound_relationship_test

@producer
Time for compound Checks.

+relationship.producer=12
+relationship.nate=-7

@producer
I am currently at ^{%relationship.producer}.

@producer
Nate is currently at ^{%relationship.nate}.

?relationship.producer >= 10 & ?relationship.nate <= -5
	@producer
	Both Checks passed.

	@producer
	Apparently you like me more than ^{@nate}.

?relationship.producer = 20 ~ ?relationship.nate = -7
	@producer
	The OR test passed.

	@producer
	At least one side was true.

?relationship.producer > 0 & ?relationship.producer <= 20 & ?relationship.nate < 0
	@producer
	Three-way AND passed.

	@producer
	How computational.

?relationship.producer < 0 ~ ?relationship.nate < 0
	@producer
	Another OR passed.

	@producer
	This time because ^{@nate} is miserable.

-> producer_end


-- CHOICE AVAILABILITY TEST

:: relationship_choice_test

@producer
These options should appear or disappear based on relationship values.

> Best-friend option.
	?relationship.producer >= 15
	@producer
	You unlocked the suspiciously affectionate option.

	+relationship.producer+2
	->  producer_end


> Friendly option.
	?relationship.producer >= 5 & ?relationship.producer < 15
	@producer
	You unlocked the normal friendly option.

	+relationship.producer+1
	->  producer_end


> Neutral option.
	?relationship.producer > -5 & ?relationship.producer < 5
	@producer
	Perfectly neutral.

	->  producer_end


> Hostile option.
	?relationship.producer <= -5
	@producer
	Ah.

	@producer
	The unpleasant option.

	+relationship.producer-2
	->  producer_end


> Always available escape hatch.
	@producer
	Coward.

	->  producer_end


-- PRODUCER END

:: producer_end

@producer
Goodbye.

@producer
Please stop turning interpersonal relationships into integers.