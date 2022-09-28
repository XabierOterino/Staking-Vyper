# @version 0.3.6
interface IERC20:
    def transfer(to:address, amount:uint256):nonpayable
    def transferFrom(_from:address, to:address, amount:uint256):nonpayable
    def balanceOf(account:address) -> uint256 : view

STAKING_TOKEN:public(address)
REWARD_TOKEN:public(address)
owner:public(address)
duration:public(uint256)
finish_at:public(uint256)
update_at:public(uint256)
reward_rate:public(uint256)
reward_per_token:public(uint256)
user_reward_per_token_paid: public(HashMap[address, uint256])
rewards: public(HashMap[address, uint256])
total_supply:public(uint256)
balance_of:public(HashMap[address, uint256])

@external
def __init__(_staking_token:address, _reward_token:address):
    self.STAKING_TOKEN = _staking_token
    self.REWARD_TOKEN = _reward_token
    self.owner = msg.sender

@external
def last_time_reward_applicable() -> uint256:
    return self._last_time_reward_applicable()

@internal
def _last_time_reward_applicable() -> uint256:
    return self._min(self.finish_at, block.timestamp)

@external
def reward_per_token_stored() -> uint256:
    return self._reward_per_token_stored()

@internal
def _reward_per_token_stored() -> uint256:
    if self.total_supply == 0:
        return self.reward_per_token
    else:    
        return self.reward_per_token + self.reward_rate * (self._last_time_reward_applicable()) * 10 **18 / self.total_supply

@internal 
def _update_reward(account: address):
    reward:uint256 = self.reward_per_token

    if account != empty(address):
        self.rewards[account] = self._earned(account)
        self.user_reward_per_token_paid[account] = reward

@external 
def stake(amount:uint256):
    self._update_reward(msg.sender)
    IERC20(self.STAKING_TOKEN).transferFrom(msg.sender, self, amount)
    self.balance_of[msg.sender] += amount
    self.total_supply += amount

@external
def withdraw(amount:uint256):
    self._update_reward(msg.sender)
    self.balance_of[msg.sender]-=amount
    self.total_supply-=amount

@external
def earned(account:address) -> uint256:
    return self._earned(account)

@internal
def _earned(account:address) -> uint256:
    return ((self.balance_of[account] * (self._reward_per_token_stored() - self.user_reward_per_token_paid[account])) / 10**18) + self.rewards[account]


@external 
def getReward():
    reward:uint256 = self.rewards[msg.sender]
    if reward > 0:
        self.rewards[msg.sender] = 0
        IERC20(self.REWARD_TOKEN).transfer(msg.sender, reward)

@external
def set_reward_duration(duration:uint256):
    assert msg.sender == self.owner , "Only owner!"
    assert self.finish_at < block.timestamp, "reward duration not finished"
    self.duration = duration


@external
def notify_reward_amount(amount:uint256):
    assert msg.sender == self.owner , "Only owner!"
    self._update_reward(empty(address))

    if block.timestamp >= self.finish_at:
        self.reward_rate = amount / self.duration
    else :
        remaining_rewards:uint256 = (self.finish_at - block.timestamp) * self.reward_rate 
        self.reward_rate = (amount + remaining_rewards) / self.duration
    assert self.reward_rate > 0 , "Reward rate=0"
    assert self.reward_rate * self.duration <= IERC20(self.REWARD_TOKEN).balanceOf(self),"Reward amount > balance"
    
    self.finish_at = block.timestamp + self.duration
    self.update_at = block.timestamp

@internal
def _min(x:uint256, y:uint256) -> uint256:
    if x<=y:
        return x 
    else:
        return y





