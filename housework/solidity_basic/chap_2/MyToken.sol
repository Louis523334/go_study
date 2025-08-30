// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyToken {
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        _name = "LSTToken";
        _symbol = "LST";
        // _mint(msg.sender, 1000 * 10 ** _decimals);  // 初始铸造1000个代币，考虑小数位
    }

    // 代币名称
    function name() public view returns (string memory) {
        return _name;
    }

    // 代币符号
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    // 小数位
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    // 总供应量
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // 查询余额
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    // 转账
    function transfer(address to, uint256 amount) public returns (bool) {
        require(to != address(0), "Invalid recipient address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);

        return true;
    }

    // 授权别人花费自己的代币
    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "Invalid spender address");

        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        return true;
    }

    // 查询授权额度
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowance[owner][spender];
    }

    // 代币委托转账
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(to != address(0), "Invalid recipient address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowance[from][msg.sender] >= amount, "Allowance exceeded");

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowance[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);

        return true;
    }

    // 铸造代币（private修饰，自己调用）
    function _mint(address account, uint256 amount) public {
        require(account != address(0), "Invalid account");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}